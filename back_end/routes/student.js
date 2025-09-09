const { Router } = require("express");
const { z } = require("zod");
const jwt = require("jsonwebtoken");
const { User } = require("../db");
const { auth } = require("../auth");
require("dotenv").config();

const JWT_SECRET = process.env.JWT_SECRET;
const studentRouter = Router();

// --- Zod Schema for Input Validation ---
// The signup schema has been removed as it's no longer needed.
const signinSchema = z.object({
  email: z.string().email(),
  rollNo: z.string().min(1, { message: "Roll number is required." }),
  password: z.string().min(8, { message: "Password is required." }),
});

/**
 * @route   POST /student/signin
 * @desc    Authenticates a student and returns a JWT
 * @access  Public
 */
studentRouter.post("/signin", async (req, res) => {
  // 1. Validate input
  const result = signinSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({
      message: "Invalid input data.",
      errors: result.error.flatten().fieldErrors,
    });
  }
  const { rollNo, password } = result.data;

  try {
    // 2. Find user by roll number
    const user = await User.findOne({ rollNo });

    // If no user or if a password was never set by an admin
    if (!user || !user.password) {
      return res
        .status(401)
        .json({ message: "Invalid credentials or account does not exist." });
    }

    // 3. Compare the provided password with the stored hash using our model method
    const isMatch = await user.comparePassword(password);

    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials." });
    }

    // 4. If password matches, create JWT payload
    const payload = {
      name : user.name,
      rollNo: user.rollNo,
    };

    // 5. Sign the token
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: "1d" }); // Token expires in 1 day
    console.log("sign in successfully");
    // 6. Send token to client
    res.status(200).json({
      message: "Signed in successfully.",
      interestsSelected : user.interestsSelected,
      token: token,
    });
  } catch (error) {
    console.error("Error during student signin:", error);
    res.status(500).json({ message: "An internal server error occurred." });
  }
});

// POST /student/interests
studentRouter.post("/interests", async (req, res) => {
  try {
    const { rollNo, interests } = req.body;

    if (!rollNo || !Array.isArray(interests)) {
      return res
        .status(400)
        .json({ message: "rollNo and interests array are required" });
    }

    const user = await User.findOne({ rollNo });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    let updateFields = { interests };
    if (!user.interestsSelected) {
      updateFields.interestsSelected = true;
    }

    const updatedUser = await User.findOneAndUpdate(
      { rollNo },
      { $set: updateFields },
      { new: true }
    );

    res.json({
      message: "Interests updated successfully",
      interests: updatedUser.interests,
      interestsSelected: updatedUser.interestsSelected,
    });
  } catch (error) {
    console.error("Error updating interests:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});

studentRouter.get('/profile' , auth ,  function(req , res){
    // The 'auth' middleware decodes the JWT and attaches the payload to req.user.
    // The payload contains the user's name as defined in the /signin route.
    const userName = req.user.name;

    if (!userName) {
        return res.status(400).json({ message: "User name not found in token." });
    }

    // Return the name from the token payload
    res.status(200).json({
        name: userName
    });
})

module.exports = studentRouter;

