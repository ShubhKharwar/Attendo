const { Router } = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { User, TemporaryPassword } = require('../db'); // Import both models
const { extractInfoFromImage } = require('../utils/gemini');

const adminRouter = Router();

// Configure Multer to store uploaded files in memory
const storage = multer.memoryStorage();
const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 } // Limit file size to 5MB
});

// Helper function to generate a simple random password
const generatePassword = () => {
    // Generates an 8-character long random string (e.g., 'a1b2c3d4')
    return crypto.randomBytes(4).toString('hex');
};

/**
 * @route   POST /admin/upload
 * @desc    Upload an image, extract info, auto-generate passwords, and save everything to the DB
 * @access  Public (for demonstration)
 */
adminRouter.post('/upload', upload.single('idCardImage'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No image file uploaded.' });
        }

        console.log('Sending image to Gemini for processing...');
        const extractedDataArray = await extractInfoFromImage(req.file.buffer, req.file.mimetype);

        if (!Array.isArray(extractedDataArray) || extractedDataArray.length === 0) {
            return res.status(400).json({ message: 'Could not extract any user entries from the image.' });
        }
        
        console.log(`Extracted ${extractedDataArray.length} potential user(s) from the image.`);

        const validUsersToInsert = [];
        const tempPasswordsToStore = [];
        const invalidEntries = [];

        // 4. Filter, validate, and generate passwords
        for (const entry of extractedDataArray) {
            if (entry.name && entry.rollNo && entry.email && entry.college) {
                // Generate a password for the new user
                const password = generatePassword();

                // Prepare the user object with the new password for the User collection.
                // The pre-save hook in your User model will hash this password automatically.
                validUsersToInsert.push({ ...entry, password });

                // Prepare the temporary password object for the TemporaryPassword collection
                tempPasswordsToStore.push({ rollNo: entry.rollNo, password });
            } else {
                invalidEntries.push({ reason: 'Missing one or more required fields.', data: entry });
            }
        }

        if (validUsersToInsert.length === 0) {
            return res.status(400).json({
                message: 'No complete and valid user entries could be processed from the image.',
                errors: invalidEntries
            });
        }
        
        // 5. Insert users and their temporary passwords into the database
        let createdUsers = [];
        try {
            // Step 5a: Insert all valid users. The passwords will be hashed by the model's pre-save hook.
            createdUsers = await User.insertMany(validUsersToInsert, { ordered: false });

            // Step 5b: If user insertion was successful, store the temporary plain-text passwords.
            // We only want to store passwords for users that were actually created.
            const successfulRollNos = new Set(createdUsers.map(u => u.rollNo));
            const finalTempPasswords = tempPasswordsToStore.filter(p => successfulRollNos.has(p.rollNo));

            if (finalTempPasswords.length > 0) {
                // We don't need to handle errors here as duplicates are unlikely if user creation succeeded.
                await TemporaryPassword.insertMany(finalTempPasswords, { ordered: false });
            }

        } catch (error) {
            // This block handles partial success, e.g., when some users are duplicates.
            if (error.code === 11000 && error.result && error.result.nInserted > 0) {
                const successCount = error.result.nInserted;
                console.log(`${successCount} user(s) were saved before a duplicate key error.`);

                // Find out which users were successfully inserted to save their temp passwords
                const writeErrorsDetails = error.writeErrors.map(e => e.op.rollNo);
                const successfulInserts = validUsersToInsert.filter(u => !writeErrorsDetails.includes(u.rollNo));
                const successfulRollNos = new Set(successfulInserts.map(u => u.rollNo));
                const finalTempPasswords = tempPasswordsToStore.filter(p => successfulRollNos.has(p.rollNo));

                if (finalTempPasswords.length > 0) {
                   try {
                     await TemporaryPassword.insertMany(finalTempPasswords, { ordered: false });
                   } catch (tempPassError) {
                     // Log this but don't fail the whole request
                     console.error("Failed to insert some temporary passwords during partial success:", tempPassError);
                   }
                }
                
                return res.status(207).json({
                    message: `Partial success. ${successCount} new user(s) were created.`,
                    successfulInserts: successCount,
                    // Provide the passwords for successfully created users
                    createdUsersWithPasswords: finalTempPasswords,
                    failedInserts: error.writeErrors.map(e => ({ message: `Duplicate key error.`, detail: e.err.errmsg })),
                    malformedEntries: invalidEntries,
                });
            }
            // If it's a different kind of DB error, re-throw to the outer catch block.
            throw error;
        }

        // 6. Send a final success response, including the generated passwords for the admin
        res.status(201).json({
            message: `Successfully created ${createdUsers.length} user(s).`,
            // Return the created user info along with their generated plain-text passwords
            createdUsersWithPasswords: tempPasswordsToStore,
            malformedEntries: invalidEntries
        });

    } catch (error) {
        console.error('Error during image upload and processing:', error);
        // Avoid sending a generic error if a specific one (like 207 Multi-Status) was already sent
        if (error.code !== 11000) {
            res.status(500).json({ message: 'An internal server error occurred.' });
        }
    }
});

module.exports = adminRouter;

