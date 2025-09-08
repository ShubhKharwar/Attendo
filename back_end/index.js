// index.js

// 1. Configure environment variables at the very top
require('dotenv').config();

const express = require('express');
const { connectDB } = require('./db'); // Import the connectDB function
const studentRouter = require('./routes/student');
const adminRouter = require('./routes/admin');
const cors = require('cors')


const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON bodies
app.use(express.json());
app.use(cors())

// Set up your routes
app.use('/api/v1/student', studentRouter);
app.use('/api/v1/admin', adminRouter);

// Function to start the server
const startServer = async () => {
  try {
    // 2. Connect to the database
    await connectDB();

    // 3. Start listening for requests ONLY after the database is connected
    app.listen(PORT, () => {
      console.log(`Server is running successfully on port ${PORT}`);
    });
  } catch (error) {
    console.error("Failed to connect to the database.", error);
    process.exit(1);
  }
};

// 4. Run the startup function
startServer();