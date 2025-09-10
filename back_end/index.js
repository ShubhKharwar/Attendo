// index.js

// 1. Configure environment variables at the very top. This MUST be first.
require('dotenv').config();

// 2. Set the global DNS lookup order to prefer IPv4.
// This is the clean, robust fix for the ETIMEDOUT/ENETUNREACH network errors.
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

// 3. Import all other modules
const express = require('express');
const cors = require('cors');
const { connectDB } = require('./db'); // Assuming db.js exports this
const studentRouter = require('./routes/student');
const adminRouter = require('./routes/admin');

// 4. Initialize Express App
const app = express();
const PORT = process.env.PORT || 3000;

// 5. Apply Middleware
app.use(cors());
app.use(express.json()); // Middleware to parse JSON bodies

// 6. Define API Routes
app.get('/', (req, res) => {
    res.status(200).send('<h1>Attendo API is running!</h1>');
});
app.use('/api/v1/student', studentRouter);
app.use('/api/v1/admin', adminRouter);

// 7. Function to start the server
const startServer = async () => {
    try {
        // Connect to the database first
        await connectDB();

        // Start listening for requests only after the database is connected
        app.listen(PORT, () => {
            console.log(`Server is running successfully on port ${PORT}`);
        });
    } catch (error) {
        console.error("Failed to start server:", error);
        process.exit(1);
    }
};

// 8. Run the startup function
startServer();