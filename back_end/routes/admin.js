// routes/adminRouter.js

const { Router } = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { User, TemporaryPassword } = require('../db');
const { extractInfoFromPdf, extractTimetableFromPdf } = require('../utils/gemini');
const { auth } = require('../auth')
const jwt = require('jsonwebtoken');

const adminRouter = Router();

// helper: "2025-09-10" -> "Wednesday"
function dayNameFromISO(isoDate) {
  const d = new Date(`${isoDate}T00:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  const names = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  return names[d.getDay()];
}

// helper: "09:00" -> 540
function timeToMinutes(t) {
  const [h, m] = String(t).split(':').map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

// Multer and generatePassword functions remain the same
const storage = multer.memoryStorage();
const upload = multer({
    storage: storage,
    limits: { fileSize: 10 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'application/pdf') {
            cb(null, true);
        } else {
            cb(new Error('Invalid file type. Only PDF files are allowed.'), false);
        }
    }
});
const generatePassword = () => crypto.randomBytes(4).toString('hex');


adminRouter.post('/upload', upload.single('studentListPdf'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No PDF file uploaded.' });
        }

        console.log('Sending PDF to Gemini for processing...');
        const extractedDataArray = await extractInfoFromPdf(req.file.buffer, req.file.mimetype);

        if (!Array.isArray(extractedDataArray) || extractedDataArray.length === 0) {
            return res.status(400).json({ message: 'Could not extract any user entries from the PDF.' });
        }
        
        const validUsersToProcess = [];
        const invalidEntries = [];

        for (const entry of extractedDataArray) {
            const hasRequiredCommonFields = entry.rollNo && entry.email && entry.name;
            const isValidUserType = entry.userType && ['student', 'admin'].includes(entry.userType);
            const hasRequiredClassForStudent = (entry.userType === 'student') ? !!entry.class : true;

            if (hasRequiredCommonFields && isValidUserType && hasRequiredClassForStudent) {
                const password = generatePassword();
                
                // --- CHANGED: Explicitly construct the user document ---
                // This ensures 'class' is handled correctly based on userType.
                const userPayload = {
                    rollNo: entry.rollNo,
                    name: entry.name,
                    email: entry.email,
                    userType: entry.userType,
                    password: password,
                    // If user is a student, use their class. Otherwise, set to 'N/A' to satisfy the
                    // schema's 'required: true' constraint without saving incorrect data.
                    class: entry.userType === 'student' ? entry.class : 'N/A',
                };
                
                validUsersToProcess.push(userPayload);

            } else {
                invalidEntries.push({ 
                    reason: 'Missing required fields. For students: rollNo, name, email, class, userType. For admins: rollNo, name, email, userType.', 
                    data: entry 
                });
            }
        }

        if (validUsersToProcess.length === 0) {
            return res.status(400).json({
                message: 'No valid user entries could be processed from the PDF.',
                errors: invalidEntries
            });
        }
        
        const createdUsers = [];
        const failedInserts = [];
        const tempPasswordsToStore = [];

        for (const userDoc of validUsersToProcess) {
            try {
                const newUser = await User.create(userDoc);
                createdUsers.push(newUser);
                tempPasswordsToStore.push({ rollNo: userDoc.rollNo, password: userDoc.password });
            } catch (error) {
                failedInserts.push({ 
                    reason: error.code === 11000 ? `Duplicate key error for rollNo: ${userDoc.rollNo}` : error.message, 
                    data: userDoc 
                });
            }
        }

        if (tempPasswordsToStore.length > 0) {
            try {
                await TemporaryPassword.insertMany(tempPasswordsToStore, { ordered: false });
            } catch (tempPassError) {
                console.error("Error inserting some temporary passwords:", tempPassError);
            }
        }
        
        if (failedInserts.length > 0 && createdUsers.length > 0) {
            return res.status(207).json({
                message: `Partial success. ${createdUsers.length} new user(s) were created.`,
                successfulInserts: createdUsers.length,
                createdUsersWithPasswords: tempPasswordsToStore,
                failedInserts: failedInserts,
                malformedEntries: invalidEntries,
            });
        }

        if (failedInserts.length > 0 && createdUsers.length === 0) {
            return res.status(409).json({
                message: `Operation failed. No new users were created.`,
                failedInserts: failedInserts,
                malformedEntries: invalidEntries,
            });
        }

        res.status(201).json({
            message: `Successfully created ${createdUsers.length} user(s).`,
            createdUsersWithPasswords: tempPasswordsToStore,
            malformedEntries: invalidEntries,
        });

    } catch (error) {
        console.error('Error during PDF upload and processing:', error);
        if (!res.headersSent) {
             res.status(500).json({ message: error.message || 'An internal server error occurred.' });
        }
    }
});


adminRouter.post('/upload-timetable', upload.single('timetablePdf'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No timetable PDF file uploaded.' });
        }

        console.log('Sending timetable PDF to Gemini for processing...');
        const timetableEntries = await extractTimetableFromPdf(req.file.buffer, req.file.mimetype);

        if (!Array.isArray(timetableEntries) || timetableEntries.length === 0) {
            return res.status(400).json({ message: 'Could not extract any timetable entries from the PDF.' });
        }

        // --- CHANGED: Added 'teachersUpdated' to summary ---
        const summary = {
            processedEntries: 0,
            studentsUpdated: 0,
            teachersUpdated: 0,
            errors: []
        };

        for (const entry of timetableEntries) {
            // --- CHANGED: Now validating 'teacherEmail' is also present ---
            if (!entry.subjectCode || !entry.class || !entry.day || !entry.startTime || !entry.endTime || !entry.teacherEmail) {
                summary.errors.push({
                    reason: 'Skipped entry due to missing required fields (subjectCode, class, day, startTime, endTime, teacherEmail).',
                    data: entry
                });
                continue;
            }

            try {
                const startTime = new Date(`1970-01-01T${entry.startTime}:00Z`);
                const endTime = new Date(`1970-01-01T${entry.endTime}:00Z`);
                
                if (isNaN(startTime.getTime()) || isNaN(endTime.getTime()) || endTime <= startTime) {
                    summary.errors.push({
                        reason: `Invalid time format or logic (startTime: ${entry.startTime}, endTime: ${entry.endTime}).`,
                        data: entry
                    });
                    continue;
                }

                const durationInMinutes = (endTime.getTime() - startTime.getTime()) / 60000;

                const subjectInfoT = {
                    SubjectCode: entry.subjectCode,
                    Day: entry.day,
                    StartTime: entry.startTime,
                    DurationOfClass: `${durationInMinutes} minutes`,
                    Class : entry.class
                };

                const subjectInfoS = {
                    SubjectCode: entry.subjectCode,
                    Day: entry.day,
                    StartTime: entry.startTime,
                    DurationOfClass: `${durationInMinutes} minutes`,
                };

                // 1. Update all students in the specified class
                const studentUpdateResult = await User.updateMany(
                    { class: entry.class, userType: 'student' },
                    { $push: { SubjectsInfo: subjectInfoS } }
                );
                
                if (studentUpdateResult.modifiedCount > 0) {
                    summary.studentsUpdated += studentUpdateResult.modifiedCount;
                }

                // --- ADDED: Logic to update the teacher's record ---
                // 2. Update the teacher (admin user) identified by email
                const teacherUpdateResult = await User.updateOne(
                    { email: entry.teacherEmail, userType: 'admin' },
                    { $push: { SubjectsInfo: subjectInfoT } }
                );

                if (teacherUpdateResult.modifiedCount > 0) {
                    summary.teachersUpdated++;
                }
                
                summary.processedEntries++;

            } catch (dbError) {
                console.error(`Database error for class ${entry.class}:`, dbError);
                summary.errors.push({
                    reason: `Database error: ${dbError.message}`,
                    data: entry
                });
            }
        }
        
        if (summary.processedEntries === 0 && summary.errors.length > 0) {
             return res.status(400).json({
                message: 'Failed to process any timetable entries due to data errors.',
                summary: summary
            });
        }

        res.status(200).json({
            message: 'Timetable processed successfully.',
            summary: summary
        });

    } catch (error) {
        console.error('Error during timetable upload and processing:', error);
        if (!res.headersSent) {
            res.status(500).json({ message: error.message || 'An internal server error occurred.' });
        }
    }
});




adminRouter.get('/schedule',async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ message: 'Missing date query param (yyyy-MM-dd).' });
    }

    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
      return res.status(401).json({ message: 'Missing Bearer token.' });
    }

    // verify token and read payload (expects rollNo and name)
    let payload;
    try {
      payload = jwt.verify(token, process.env.JWT_SECRET);
    } catch (e) {
      return res.status(401).json({ message: 'Invalid or expired token.' });
    }

    const day = dayNameFromISO(date);
    if (!day) {
      return res.status(400).json({ message: 'Invalid date format. Use yyyy-MM-dd.' });
    }

    // find teacher by rollNo from token
    const teacher = await User.findOne(
      { rollNo: payload.rollNo, userType: 'admin' },
      { name: 1, rollNo: 1, SubjectsInfo: 1, _id: 0 }
    ).lean();

    if (!teacher) {
      return res.status(404).json({ message: 'Teacher not found.' });
    }

    const todays = (teacher.SubjectsInfo || [])
      .filter(s => String(s.Day).toLowerCase() === day.toLowerCase())
      .sort((a, b) => timeToMinutes(a.StartTime) - timeToMinutes(b.StartTime))
      .map(s => ({
        subject: s.SubjectCode,
        class: s.Class,            // present for teacher entries
        startTime: s.StartTime,
        duration: s.DurationOfClass
      }));

    return res.status(200).json({
      teacher: { name: teacher.name, rollNo: teacher.rollNo },
      date,
      day,
      classes: todays
    });
  } catch (err) {
    console.error('GET /admin/schedule error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});


adminRouter.get('/courses', auth, async (req, res) => {
    try {
        // 1. Get student's roll number from the decoded JWT payload.
        // Updated from 'rollNumber' to 'rollNo' to match your schema.
        const TeacherRollNo = req.user.rollNo;
        const TeacherName = req.user.name


        // 2. Find the student in the database using their roll number.
        // Using the User model now.
        const teacher = await User.findOne({ rollNo : TeacherRollNo , name : TeacherName , userType : "admin" });

        if (!teacher) {
            return res.status(404).json({ message: 'Teacher not found.' });
        }

        const teacherInfo = teacher.SubjectsInfo;

        if (!teacherInfo || teacherInfo.length === 0) {
            // Return an empty array if the student has no subject information.
            return res.status(200).json([]);
        }

        const uniqueSubjects = teacherInfo.filter((subject, index, self) =>
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



module.exports = adminRouter;