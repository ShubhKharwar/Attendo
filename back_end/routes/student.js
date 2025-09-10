const { Router } = require("express");
const { z } = require("zod");
const jwt = require("jsonwebtoken");
// Add this import at the top of student.js:
const axios = require("axios"); // npm install axios if not already installed
const { DailyRecommendedTask } = require("../db"); // Add this import
const { User } = require("../db");
const { auth } = require("../auth");
require("dotenv").config();

const JWT_SECRET = process.env.JWT_SECRET;
const studentRouter = Router();

// routes/student.js - Add these helper functions after imports

// Helper functions for time calculations
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return hours * 60 + minutes;
}

function minutesToTime(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
}

function dayNameFromISO(isoDate) {
  const d = new Date(`${isoDate}T00:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  const names = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  return names[d.getDay()];
}

// Smart time slot assignment for recommendations
function assignTimeSlots(existingClasses, recommendations, date) {
  const workingHours = {
    start: 9 * 60,  // 9:00 AM in minutes
    end: 18 * 60    // 6:00 PM in minutes
  };

  // Convert existing classes to busy time slots
  const busySlots = existingClasses.map(cls => ({
    start: timeToMinutes(cls.StartTime),
    end: timeToMinutes(cls.StartTime) + parseInt(cls.DurationOfClass?.replace(' minutes', '') || '60')
  })).sort((a, b) => a.start - b.start);

  // Find available time gaps
  const availableSlots = [];
  let currentTime = workingHours.start;

  for (const busySlot of busySlots) {
    // Add gap before this busy slot
    if (currentTime < busySlot.start) {
      const gapDuration = busySlot.start - currentTime;
      if (gapDuration >= 10) { // Only consider gaps of 10+ minutes
        availableSlots.push({
          start: currentTime,
          end: busySlot.start,
          duration: gapDuration
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
        duration: finalDuration
      });
    }
  }

  // Assign time slots to recommendations based on priority
  const scheduledRecommendations = [];
  let slotIndex = 0;

  // Sort recommendations by urgency and rank
  const sortedRecs = [...recommendations].sort((a, b) => {
    const urgencyWeight = { high: 3, medium: 2, low: 1 };
    return (urgencyWeight[b.urgency_level] || 2) - (urgencyWeight[a.urgency_level] || 2) || 
           (a.rank || 1) - (b.rank || 1);
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
          difficultyLevel: rec.difficulty_level || "medium"
        });

        // Update the slot
        slot.start += taskDuration + 5; // Add 5min buffer
        slot.duration -= (taskDuration + 5);
        
        if (slot.duration < 10) { // Less than 10 minutes left
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
      user.markModified('attendanceLog');
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

// studentRouter.js

// Helpers (place near the top of this file)
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

function timeToMinutes(t) {
  const [h, m] = String(t).split(":").map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

// GET /student/schedule?date=yyyy-MM-dd
// Requires Authorization: Bearer <token>
// UPDATE your existing GET /schedule route in routes/student.js
studentRouter.get('/schedule', auth, async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ message: 'Missing date query param (yyyy-MM-dd).' });
    }

    const { rollNo } = req.user || {};
    if (!rollNo) {
      return res.status(401).json({ message: 'Unauthorized: missing token payload.' });
    }

    const day = dayNameFromISO(date);
    if (!day) {
      return res.status(400).json({ message: 'Invalid date format. Use yyyy-MM-dd.' });
    }

    // Fetch student data
    const student = await User.findOne(
      { rollNo, userType: 'student' },
      { name: 1, rollNo: 1, class: 1, SubjectsInfo: 1, _id: 1 }
    ).lean();

    if (!student) {
      return res.status(404).json({ message: 'Student not found.' });
    }

    // Get regular classes for the day
    const regularClasses = (student.SubjectsInfo || [])
      .filter(s => String(s.Day).toLowerCase() === day.toLowerCase())
      .sort((a, b) => timeToMinutes(a.StartTime) - timeToMinutes(b.StartTime))
      .map(s => ({
        subject: s.SubjectCode,
        class: student.class,
        startTime: s.StartTime,
        duration: s.DurationOfClass,
        type: 'class',
        isOfficial: true
      }));

    let allTasks = [...regularClasses];

    // Get recommended tasks for the date
    try {
      const recommendedTasks = await DailyRecommendedTask.findOne({
        student: student._id,
        date: date
      }).lean();

      if (recommendedTasks && recommendedTasks.tasks.length > 0) {
        const recommendationTasks = recommendedTasks.tasks
          .filter(task => task.suggestedStartTime) // Only include tasks with assigned time slots
          .map(task => ({
            subject: task.title,
            class: 'Recommended',
            startTime: task.suggestedStartTime,
            duration: `${task.estimatedTime} minutes`,
            type: 'recommendation',
            isOfficial: false,
            reasoning: task.reasoning,
            urgencyLevel: task.urgencyLevel,
            taskType: task.taskType,
            taskId: task.taskId
          }));

        allTasks = [...regularClasses, ...recommendationTasks];
      }
    } catch (recError) {
      console.error('Error fetching recommendations for schedule:', recError);
    }

    // Sort all tasks by start time
    allTasks.sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));

    return res.status(200).json({
      student: { name: student.name, rollNo: student.rollNo, class: student.class },
      date,
      day,
      classes: allTasks
    });

  } catch (err) {
    console.error('GET /student/schedule error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

studentRouter.get("/courses", auth, async (req, res) => {
  try {
    // 1. Get student's roll number from the decoded JWT payload.
    // Updated from 'rollNumber' to 'rollNo' to match your schema.
    const studentRollNo = req.user.rollNo;

    if (!studentRollNo) {
      return res
        .status(400)
        .json({ message: "Roll number not found in token." });
    }

    // 2. Find the student in the database using their roll number.
    // Using the User model now.
    const student = await User.findOne({ rollNo: studentRollNo });

    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // 3. Get the SubjectsInfo array directly from the student document.
    const subjectsInfo = student.SubjectsInfo;

    if (!subjectsInfo || subjectsInfo.length === 0) {
      // Return an empty array if the student has no subject information.
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

    // 4. Return the list of subjects as JSON
    res.status(200).json(Subjects);
  } catch (error) {
    console.error("Error fetching student courses:", error);
    res.status(500).json({ message: "Server error. Please try again later." });
  }
});


// Add this NEW ROUTE after your existing routes:
// ADD THIS NEW ROUTE in routes/student.js
studentRouter.get('/recommendations', auth, async (req, res) => {
  try {
    const rollNo = req.user.rollNo;
    const date = req.query.date || new Date().toISOString().slice(0, 10);

    // Find student
    const student = await User.findOne({ rollNo, userType: 'student' });
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }

    // Check if recommendations already exist for this date
    const existingRecs = await DailyRecommendedTask.findOne({ 
      student: student._id, 
      date 
    });

    if (existingRecs) {
      return res.json({ 
        tasks: existingRecs.tasks, 
        cached: true,
        generatedAt: existingRecs.generatedAt
      });
    }

    // Generate new recommendations for today only
    if (date === new Date().toISOString().slice(0, 10)) {
      try {
        // Get student's schedule for the day to find available time slots
        const day = dayNameFromISO(date);
        const todaysClasses = (student.SubjectsInfo || [])
          .filter(s => String(s.Day).toLowerCase() === day?.toLowerCase());

        // Prepare request for Python FastAPI
        const ragRequest = {
          user_id: rollNo,
          break_duration_minutes: parseInt(req.query.duration) || 15,
          current_courses: [...new Set(student.SubjectsInfo.map(s => s.SubjectCode))],
          interests: student.interests || [],
          recent_attendance: {} // You can enhance this based on attendanceLog
        };

        // Call Python FastAPI service
        const response = await axios.post('http://localhost:8000/recommendations/', ragRequest, {
          timeout: 10000
        });
        
        const recommendations = response.data;

        if (recommendations && recommendations.length > 0) {
          // Assign time slots based on existing schedule
          const scheduledTasks = assignTimeSlots(todaysClasses, recommendations, date);

          // Save to MongoDB
          const dailyRec = new DailyRecommendedTask({
            student: student._id,
            date,
            tasks: scheduledTasks
          });
          
          await dailyRec.save();
          return res.json({ 
            tasks: dailyRec.tasks, 
            cached: false,
            generatedAt: dailyRec.generatedAt
          });
        }
      } catch (apiError) {
        console.error('Error calling RAG API:', apiError.message);
        // Fall through to return empty array
      }
    }

    res.json({ tasks: [], cached: false });

  } catch (error) {
    console.error('Error fetching recommendations:', error);
    res.status(500).json({ message: 'Server error' });
  }
});


module.exports = studentRouter;
