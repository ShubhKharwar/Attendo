// routes/adminRouter.js

const { Router } = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { User, TemporaryPassword } = require('../db');
const { extractInfoFromPdf } = require('../utils/gemini');

const adminRouter = Router();

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
            if (entry.rollNo && entry.email) {
                const password = generatePassword();
                validUsersToProcess.push({
                    rollNo: entry.rollNo,
                    email: entry.email,
                    password: password // Plain text password
                });
            } else {
                invalidEntries.push({ reason: 'Missing required fields (rollNo or email).', data: entry });
            }
        }

        if (validUsersToProcess.length === 0) {
            return res.status(400).json({
                message: 'No valid user entries could be processed from the PDF.',
                errors: invalidEntries
            });
        }
        
        // --- THIS ENTIRE DATABASE BLOCK IS REPLACED ---
        const createdUsers = [];
        const failedInserts = [];
        const tempPasswordsToStore = [];

        // Loop and create each user individually to trigger the 'save' hook
        for (const userDoc of validUsersToProcess) {
            try {
                // User.create() will trigger the pre-save hook that hashes the password
                const newUser = await User.create(userDoc);
                createdUsers.push(newUser);
                // Only store temp passwords for successfully created users
                tempPasswordsToStore.push({ rollNo: userDoc.rollNo, password: userDoc.password });
            } catch (error) {
                if (error.code === 11000) { // Handle duplicate key errors
                    failedInserts.push({ 
                        reason: `Duplicate key error for rollNo: ${userDoc.rollNo}`, 
                        data: userDoc 
                    });
                } else {
                    // Handle other validation errors
                    failedInserts.push({ reason: error.message, data: userDoc });
                }
            }
        }

        // Now, insert the temporary passwords for the users that were successfully created
        if (tempPasswordsToStore.length > 0) {
            try {
                await TemporaryPassword.insertMany(tempPasswordsToStore, { ordered: false });
            } catch (tempPassError) {
                // Log this error but don't fail the entire request
                console.error("Error inserting some temporary passwords:", tempPassError);
            }
        }
        
        // Send a final response based on the outcome
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
            return res.status(409).json({ // 409 Conflict
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

module.exports = adminRouter;