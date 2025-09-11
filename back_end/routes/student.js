const { Router } = require("express");
const { z } = require("zod");
const jwt = require("jsonwebtoken");
// Add this import at the top of student.js:
const axios = require("axios"); // npm install axios if not already installed
const { DailyRecommendedTask } = require("../db"); // Add this import
const { User } = require("../db");
const { auth } = require("../auth");
// Import the new Gemini helper function
const { getChatbotResponse } = require("../utils/gemini");
require("dotenv").config();

const JWT_SECRET = process.env.JWT_SECRET;
const studentRouter = Router();

// routes/student.js - Add these helper functions after imports

// Helper functions for time calculations
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(":").map(Number);
  return hours * 60 + minutes;
}

// Add this helper function in student.js
async function cleanupRecommendations(studentId) {
  try {
    // Remove any recommendations older than 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoffDate = thirtyDaysAgo.toISOString().slice(0, 10);

    await DailyRecommendedTask.deleteMany({
      student: studentId,
      date: { $lt: cutoffDate },
    });

    console.log(`Cleaned up old recommendations for student ${studentId}`);
  } catch (error) {
    console.error("Error cleaning up recommendations:", error);
  }
}

function minutesToTime(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${hours.toString().padStart(2, "0")}:${mins
    .toString()
    .padStart(2, "0")}`;
}

function dayNameFromISO(isoDate) {
  const d = new Date(`${isoDate}T00:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  const names = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];
  return names[d.getDay()];
}

// Smart time slot assignment for recommendations
// Fix the assignTimeSlots function in student.js
function assignTimeSlots(existingClasses, recommendations, date) {
  const workingHours = {
    start: 9 * 60, // 9:00 AM in minutes
    end: 18 * 60, // 6:00 PM in minutes
  };

  // Convert existing classes to busy time slots
  const busySlots = existingClasses
    .map((cls) => ({
      start: timeToMinutes(cls.startTime), // Fix: use startTime instead of StartTime
      end:
        timeToMinutes(cls.startTime) +
        parseInt(cls.duration?.replace(" minutes", "") || "60"),
    }))
    .sort((a, b) => a.start - b.start);

  // Find available time gaps
  const availableSlots = [];
  let currentTime = workingHours.start;

  for (const busySlot of busySlots) {
    // Add gap before this busy slot
    if (currentTime < busySlot.start) {
      const gapDuration = busySlot.start - currentTime;
      if (gapDuration >= 10) {
        // Only consider gaps of 10+ minutes
        availableSlots.push({
          start: currentTime,
          end: busySlot.start,
          duration: gapDuration,
        });
      }
    }
    currentTime = Math.max(currentTime, busySlot.end);
  }

  // Add final slot after last class
  if (currentTime < workingHours.end) {
    const finalDuration = workingHours.end - currentTime;
    if (finalDuration >= 10) {
      availableSlots.push({
        start: currentTime,
        end: workingHours.end,
        duration: finalDuration,
      });
    }
  }

  // Assign time slots to recommendations based on priority
  const scheduledRecommendations = [];
  let slotIndex = 0;

  // Sort recommendations by urgency and rank
  const sortedRecs = [...recommendations].sort((a, b) => {
    const urgencyWeight = { high: 3, medium: 2, low: 1 };
    return (
      (urgencyWeight[b.urgency_level] || 2) -
        (urgencyWeight[a.urgency_level] || 2) ||
      (a.rank || 1) - (b.rank || 1)
    );
  });

  for (const rec of sortedRecs) {
    const taskDuration = rec.estimated_time || 15;

    // Find a suitable time slot
    while (slotIndex < availableSlots.length) {
      const slot = availableSlots[slotIndex];
      if (slot.duration >= taskDuration) {
        const startTime = minutesToTime(slot.start);
        const endTime = minutesToTime(slot.start + taskDuration);

        scheduledRecommendations.push({
          taskId: rec.task_id,
          title: rec.title,
          description: rec.description || "",
          estimatedTime: taskDuration,
          taskType: rec.task_type,
          courseTags: rec.course_tags || [],
          topicTags: rec.topic_tags || [],
          reasoning: rec.reasoning || "",
          urgencyLevel: rec.urgency_level || "medium",
          suggestedStartTime: startTime,
          suggestedEndTime: endTime,
          isScheduled: false,
          rank: rec.rank || 1,
          difficultyLevel: rec.difficulty_level || "medium",
        });

        // Update the slot
        slot.start += taskDuration + 5; // Add 5min buffer
        slot.duration -= taskDuration + 5;
        if (slot.duration < 10) {
          // Less than 10 minutes left
          slotIndex++;
        }
        break;
      } else {
        slotIndex++;
      }
    }

    // Stop if we've filled all available slots
    if (slotIndex >= availableSlots.length) {
      break;
    }
  }

  return scheduledRecommendations;
}

// --- Zod Schema for Input Validation ---
// The signup schema has been removed as it's no longer needed.
const signinSchema = z.object({
  email: z.string().email(),
  rollNo: z.string().min(1, { message: "Roll number is required." }),
  password: z.string().min(8, { message: "Password is required." }),
});

// Add a new schema for the chatbot query
const chatbotQuerySchema = z.object({
  query: z.string().min(1, { message: "Query cannot be empty." }),
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
      name: user.name,
      rollNo: user.rollNo,
    };

    // 5. Sign the token
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: "1d" }); // Token expires in 1 day
    console.log("sign in successfully");
    // 6. Send token to client
    res.status(200).json({
      message: "Signed in successfully.",
      interestsSelected: user.interestsSelected,
      userType: user.userType,
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

studentRouter.get("/profile", auth, function (req, res) {
  // The 'auth' middleware decodes the JWT and attaches the payload to req.user.
  // The payload contains the user's name as defined in the /signin route.
  const userName = req.user.name;

  if (!userName) {
    return res.status(400).json({ message: "User name not found in token." });
  }

  // Return the name from the token payload
  res.status(200).json({
    name: userName,
  });
});

// POST /student/markAttendance
studentRouter.post("/markAttendance", auth, async (req, res) => {
  try {
    const { sessionId, subject } = req.body;
    const userInfo = req.user;

    // Validation
    if (!sessionId || !subject) {
      return res
        .status(400)
        .json({ message: "sessionId and subject are required" });
    }

    // Find user
    const user = await User.findOne({ rollNo: userInfo.rollNo });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Check for duplicate session
    if (user.lastSessionId === sessionId) {
      return res.status(400).json({
        message: "Attendance already marked for this session",
      });
    }

    // Find matching subject in attendanceLog
    let attendanceEntry = user.attendanceLog.find(
      (entry) => entry.subject === subject
    );

    if (attendanceEntry) {
      // Subject found - increment presentDays
      attendanceEntry.presentDays += 1;
      // Mark the array as modified so Mongoose knows to save it
      user.markModified("attendanceLog");
    } else {
      // Subject not found - create new entry
      user.attendanceLog.push({
        subject: subject,
        presentDays: 1,
        totalDays: 0,
      });
    }

    // Update lastSessionId to prevent duplicates
    user.lastSessionId = sessionId;

    // Save changes
    await user.save();

    res.status(200).json({
      message: "Attendance marked successfully",
      subject: subject,
      sessionId: sessionId,
    });
  } catch (error) {
    console.error("Error marking attendance:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /student/schedule?date=yyyy-MM-dd
studentRouter.get("/schedule", auth, async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res
        .status(400)
        .json({ message: "Missing date query param (yyyy-MM-dd)." });
    }

    const { rollNo } = req.user || {};
    if (!rollNo) {
      return res
        .status(401)
        .json({ message: "Unauthorized: missing token payload." });
    }

    const day = dayNameFromISO(date);
    if (!day) {
      return res
        .status(400)
        .json({ message: "Invalid date format. Use yyyy-MM-dd." });
    }

    // Fetch student data
    const student = await User.findOne(
      { rollNo, userType: "student" },
      { name: 1, rollNo: 1, class: 1, SubjectsInfo: 1, interests: 1, _id: 1 }
    ).lean();

    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // Get regular classes for the day
    const regularClasses = (student.SubjectsInfo || [])
      .filter((s) => String(s.Day).toLowerCase() === day.toLowerCase())
      .sort((a, b) => timeToMinutes(a.StartTime) - timeToMinutes(b.StartTime))
      .map((s) => ({
        subject: s.SubjectCode,
        class: student.class,
        startTime: s.StartTime,
        duration: s.DurationOfClass,
        type: "class",
        isOfficial: true,
      }));

    let allTasks = [...regularClasses];

    try {
      console.log(`Looking for recommendations for exact date: ${date}`);

      const recommendedTasks = await DailyRecommendedTask.findOne({
        student: student._id,
        date: date,
      }).lean();

      const today = new Date().toISOString().slice(0, 10);
      const requestedDate = new Date(date);
      const todayDate = new Date(today);
      const daysDifference = Math.floor(
        (requestedDate - todayDate) / (1000 * 60 * 60 * 24)
      );

      const shouldGenerateRecommendations =
        !recommendedTasks && date >= today && daysDifference <= 7;

      if (shouldGenerateRecommendations) {
        console.log(`Generating NEW recommendations specifically for date: ${date}`);

        try {
          const ragRequest = {
            user_id: rollNo,
            break_duration_minutes: 15,
            current_courses: [
              ...new Set(student.SubjectsInfo.map((s) => s.SubjectCode)),
            ],
            interests: student.interests || [],
            recent_attendance: {},
            target_date: date,
          };

          const response = await axios.post(
            "http://localhost:8000/recommendations/",
            ragRequest,
            {
              timeout: 10000,
              headers: {
                "Content-Type": "application/json",
              },
            }
          );

          const recommendations = response.data;
          console.log(
            `Received ${recommendations.length} recommendations from Python API for ${date}`
          );

          if (recommendations && recommendations.length > 0) {
            const scheduledTasks = assignTimeSlots(
              regularClasses,
              recommendations,
              date
            );
            console.log(
              `Assigned time slots to ${scheduledTasks.length} recommendations for ${date}`
            );

            const newRecommendedTasks = new DailyRecommendedTask({
              student: student._id,
              date: date,
              tasks: scheduledTasks,
            });

            await newRecommendedTasks.save();
            console.log(`Saved recommendations to MongoDB for date: ${date}`);

            const recommendationTasks = scheduledTasks
              .filter((task) => task.suggestedStartTime)
              .map((task) => ({
                subject: task.title,
                class: "Recommended",
                startTime: task.suggestedStartTime,
                duration: `${task.estimatedTime} minutes`,
                type: "recommendation",
                isOfficial: false,
                reasoning: task.reasoning,
                urgencyLevel: task.urgencyLevel,
                taskType: task.taskType,
                taskId: task.taskId,
              }));

            allTasks = [...regularClasses, ...recommendationTasks];
            console.log(
              `Added ${recommendationTasks.length} NEW recommendations to schedule for ${date}`
            );
          }
        } catch (apiError) {
          console.error("Error calling RAG API:", apiError.message);
        }
      } else if (recommendedTasks && recommendedTasks.tasks.length > 0) {
        console.log(`Found existing recommendations for date: ${date}`);

        const recommendationTasks = recommendedTasks.tasks
          .filter((task) => task.suggestedStartTime)
          .map((task) => ({
            subject: task.title,
            class: "Recommended",
            startTime: task.suggestedStartTime,
            duration: `${task.estimatedTime} minutes`,
            type: "recommendation",
            isOfficial: false,
            reasoning: task.reasoning,
            urgencyLevel: task.urgencyLevel,
            taskType: task.taskType,
            taskId: task.taskId,
          }));

        allTasks = [...regularClasses, ...recommendationTasks];
        console.log(
          `Added ${recommendationTasks.length} existing recommendations to schedule for ${date}`
        );
      } else {
        console.log(`No recommendations found or generated for date: ${date}`);
      }
    } catch (recError) {
      console.error(
        `Error fetching/generating recommendations for date ${date}:`,
        recError
      );
    }

    allTasks.sort(
      (a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime)
    );

    console.log(
      `Returning schedule for ${date} with ${allTasks.length} total tasks (${
        regularClasses.length
      } classes, ${allTasks.length - regularClasses.length} recommendations)`
    );

    return res.status(200).json({
      student: {
        name: student.name,
        rollNo: student.rollNo,
        class: student.class,
      },
      date,
      day,
      classes: allTasks,
    });
  } catch (err) {
    console.error("GET /student/schedule error:", err);
    return res.status(500).json({ message: "Internal server error." });
  }
});

studentRouter.get("/courses", auth, async (req, res) => {
  try {
    const studentRollNo = req.user.rollNo;

    if (!studentRollNo) {
      return res
        .status(400)
        .json({ message: "Roll number not found in token." });
    }

    const student = await User.findOne({ rollNo: studentRollNo });

    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    const subjectsInfo = student.SubjectsInfo;

    if (!subjectsInfo || subjectsInfo.length === 0) {
      return res.status(200).json([]);
    }

    const uniqueSubjects = subjectsInfo.filter(
      (subject, index, self) =>
        index === self.findIndex((s) => s.SubjectCode === subject.SubjectCode)
    );

    const Subjects = [];

    for (let i = 0; i < uniqueSubjects.length; i++) {
      Subjects.push(uniqueSubjects[i].SubjectCode);
    }

    res.status(200).json(Subjects);
  } catch (error) {
    console.error("Error fetching student courses:", error);
    res.status(500).json({ message: "Server error. Please try again later." });
  }
});

studentRouter.get("/recommendations", auth, async (req, res) => {
  try {
    const rollNo = req.user.rollNo;
    const date = req.query.date || new Date().toISOString().slice(0, 10);

    const student = await User.findOne({ rollNo, userType: "student" });
    if (!student) {
      return res.status(404).json({ message: "Student not found" });
    }

    const existingRecs = await DailyRecommendedTask.findOne({
      student: student._id,
      date,
    });

    if (existingRecs) {
      return res.json({
        tasks: existingRecs.tasks,
        cached: true,
        generatedAt: existingRecs.generatedAt,
      });
    }

    if (date === new Date().toISOString().slice(0, 10)) {
      try {
        const day = dayNameFromISO(date);
        const todaysClasses = (student.SubjectsInfo || []).filter(
          (s) => String(s.Day).toLowerCase() === day?.toLowerCase()
        );

        const ragRequest = {
          user_id: rollNo,
          break_duration_minutes: parseInt(req.query.duration) || 15,
          current_courses: [
            ...new Set(student.SubjectsInfo.map((s) => s.SubjectCode)),
          ],
          interests: student.interests || [],
          recent_attendance: {},
        };

        const response = await axios.post(
          "http://localhost:8000/recommendations/",
          ragRequest,
          {
            timeout: 10000,
          }
        );

        const recommendations = response.data;

        if (recommendations && recommendations.length > 0) {
          const scheduledTasks = assignTimeSlots(
            todaysClasses,
            recommendations,
            date
          );

          const dailyRec = new DailyRecommendedTask({
            student: student._id,
            date,
            tasks: scheduledTasks,
          });

          await dailyRec.save();
          return res.json({
            tasks: dailyRec.tasks,
            cached: false,
            generatedAt: dailyRec.generatedAt,
          });
        }
      } catch (apiError) {
        console.error("Error calling RAG API:", apiError.message);
      }
    }

    res.json({ tasks: [], cached: false });
  } catch (error) {
    console.error("Error fetching recommendations:", error);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * @route   POST /student/chatbot
 * @desc    Gets a student's query and responds using Gemini API
 * @access  Protected
 */
studentRouter.post("/chatbot", auth, async (req, res) => {
  // 1. Validate input
  const result = chatbotQuerySchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({
      message: "Invalid input.",
      errors: result.error.flatten().fieldErrors,
    });
  }
  const { query } = result.data;
  const { rollNo } = req.user;

  try {
    // 2. Fetch student data to build context
    const student = await User.findOne({ rollNo }).lean();
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // 3. Construct a simplified context object for the AI
    const studentContext = {
      name: student.name,
      rollNo: student.rollNo,
      class: student.class,
      interests: student.interests || [],
      // Provide today's schedule as context
      schedule: (student.SubjectsInfo || [])
        .filter((s) => {
          const today = new Date().toLocaleString("en-us", { weekday: "long" });
          return String(s.Day).toLowerCase() === today.toLowerCase();
        })
        .map((s) => ({
          subject: s.SubjectCode,
          day: s.Day,
          startTime: s.StartTime,
          duration: s.DurationOfClass,
        })),
    };

    // 4. Call the Gemini API helper
    const aiResponse = await getChatbotResponse(query, studentContext);

    // 5. Send the response back to the client
    res.status(200).json({ response: aiResponse });
  } catch (error) {
    console.error("Error in /chatbot endpoint:", error);
    res
      .status(500)
      .json({ message: "An error occurred while communicating with the assistant." });
  }
});

studentRouter.get("/call", async (req, res) => {});

module.exports = studentRouter;