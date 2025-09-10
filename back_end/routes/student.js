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
      userType : user.userType,
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

// POST /student/markAttendance
studentRouter.post('/markAttendance', auth, async (req, res) => {
  try {
    const { sessionId, subject } = req.body;
    const userInfo = req.user;

    // Validation
    if (!sessionId || !subject) {
      return res.status(400).json({ message: "sessionId and subject are required" });
    }

    // Find user
    const user = await User.findOne({ rollNo: userInfo.rollNo });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Check for duplicate session
    if (user.lastSessionId === sessionId) {
      return res.status(400).json({ 
        message: "Attendance already marked for this session" 
      });
    }

    // Find matching subject in attendanceLog
    let attendanceEntry = user.attendanceLog.find(entry => entry.subject === subject);

    if (attendanceEntry) {
      // Subject found - increment presentDays
      attendanceEntry.presentDays += 1;
    } else {
      // Subject not found - create new entry
      user.attendanceLog.push({
        subject: subject,
        presentDays: 1,
        totalDays: 0
      });
    }

    // Update lastSessionId to prevent duplicates
    user.lastSessionId = sessionId;

    // Save changes
    await user.save();

    res.status(200).json({
      message: "Attendance marked successfully",
      subject: subject,
      sessionId: sessionId
    });

  } catch (error) {
    console.error("Error marking attendance:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});


// studentRouter.js

// Helpers (place near the top of this file)
function dayNameFromISO(isoDate) {
  const d = new Date(`${isoDate}T00:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  const names = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  return names[d.getDay()];
}

function timeToMinutes(t) {
  const [h, m] = String(t).split(':').map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

// GET /student/schedule?date=yyyy-MM-dd
// Requires Authorization: Bearer <token>
studentRouter.get('/schedule', auth, async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ message: 'Missing date query param (yyyy-MM-dd).' });
    }

    // req.user is set by auth middleware after JWT verification
    const { rollNo } = req.user || {};
    if (!rollNo) {
      return res.status(401).json({ message: 'Unauthorized: missing token payload.' });
    }

    const day = dayNameFromISO(date);
    if (!day) {
      return res.status(400).json({ message: 'Invalid date format. Use yyyy-MM-dd.' });
    }

    // Fetch only needed fields
    const student = await User.findOne(
      { rollNo, userType: 'student' },
      { name: 1, rollNo: 1, class: 1, SubjectsInfo: 1, _id: 0 }
    ).lean();

    if (!student) {
      return res.status(404).json({ message: 'Student not found.' });
    }

    const todays = (student.SubjectsInfo || [])
      .filter(s => String(s.Day).toLowerCase() === day.toLowerCase())
      .sort((a, b) => timeToMinutes(a.StartTime) - timeToMinutes(b.StartTime))
      .map(s => ({
        subject: s.SubjectCode,
        class: student.class,       // students’ entries don’t carry Class; use profile class
        startTime: s.StartTime,
        duration: s.DurationOfClass
      }));

    return res.status(200).json({
      student: { name: student.name, rollNo: student.rollNo, class: student.class },
      date,
      day,
      classes: todays
    });
  } catch (err) {
    console.error('GET /student/schedule error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

studentRouter.get('/courses', auth, async (req, res) => {
    try {
        // 1. Get student's roll number from the decoded JWT payload.
        // Updated from 'rollNumber' to 'rollNo' to match your schema.
        const studentRollNo = req.user.rollNo;

        if (!studentRollNo) {
            return res.status(400).json({ message: 'Roll number not found in token.' });
        }

        // 2. Find the student in the database using their roll number.
        // Using the User model now.
        const student = await User.findOne({ rollNo: studentRollNo });

        if (!student) {
            return res.status(404).json({ message: 'Student not found.' });
        }

        // 3. Get the SubjectsInfo array directly from the student document.
        const subjectsInfo = student.SubjectsInfo;

        if (!subjectsInfo || subjectsInfo.length === 0) {
            // Return an empty array if the student has no subject information.
            return res.status(200).json([]);
        }

        const uniqueSubjects = subjectsInfo.filter((subject, index, self) =>
            index === self.findIndex((s) => (
                s.SubjectCode === subject.SubjectCode
            ))
        );

        const Subjects = []

        for(let i = 0 ; i < uniqueSubjects.length ; i++){
          Subjects.push(uniqueSubjects[i].SubjectCode)
        }

        // 4. Return the list of subjects as JSON
        res.status(200).json(Subjects);

    } catch (error) {
        console.error('Error fetching student courses:', error);
        res.status(500).json({ message: 'Server error. Please try again later.' });
    }
});

module.exports = studentRouter