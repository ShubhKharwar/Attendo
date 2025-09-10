// utils/gemini.js

const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize the Google Generative AI client
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

function fileToGenerativePart(buffer, mimeType) {
  return {
    inlineData: {
      data: buffer.toString("base64"),
      mimeType
    },
  };
}

/**
 * Extracts student information from a PDF list. (This function remains unchanged)
 */
async function extractInfoFromPdf(pdfBuffer, mimeType) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash-latest" });

    const prompt = `
      From the provided PDF document, which contains a list of users, extract the following information for each person:
      1. Full Name (as "name")
      2. Roll Number or ID (as "rollNo")
      3. Email Address (as "email")
      4. User Type (as "userType"). The userType must be either 'student' or 'admin'.
      5. Class or Section (as "class"). This field is mainly for students.

      Please return the information ONLY in a valid JSON array format, where each object in the array represents one user.
      Example format:
      [
        {
          "name": "Jane Doe",
          "rollNo": "CB.EN.U4XYZ21002",
          "email": "jane.doe@university.edu",
          "userType": "student",
          "class": "CSE-B / (N/A for userType admin"
        }
      ]
      If a class is not specified for an admin, that field can be omitted for that entry.
      If the document is empty or no user data can be found, return an empty array [].
      Do not include any other text, explanations, or markdown formatting around the JSON array.
    `;
    
    const pdfPart = fileToGenerativePart(pdfBuffer, mimeType);
    const result = await model.generateContent([prompt, pdfPart]);
    const response = await result.response;
    const text = response.text();
    const jsonString = text.replace(/```json/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonString);
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    throw new Error("Failed to extract information from PDF via Gemini API.");
  }
}

/**
 * Extracts timetable information from a PDF.
 * @param {Buffer} pdfBuffer The buffer of the PDF file.
 * @param {string} mimeType The MIME type of the PDF.
 * @returns {Promise<Array<object>>} A promise resolving to an array of timetable entry objects.
 */
async function extractTimetableFromPdf(pdfBuffer, mimeType) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash-latest" });

    // --- CHANGED: Updated prompt to include 'teacherEmail' ---
    const prompt = `
      From the provided PDF document, which contains a class timetable, extract the schedule for each class session.
      For each session, identify the following details:
      1. Subject Code (as "subjectCode")
      2. Class or Section identifier (e.g., "CSE-A") (as "class")
      3. Day of the week (as "day")
      4. Start time in HH:MM format (24-hour) (as "startTime")
      5. End time in HH:MM format (24-hour) (as "endTime")
      6. Teacher's Email Address (as "teacherEmail")

      Please return the information ONLY in a valid JSON array format. Each object should represent one class session.
      Example format:
      [
        {
          "subjectCode": "CS305",
          "class": "CSE-A",
          "day": "Monday",
          "startTime": "09:00",
          "endTime": "10:00",
          "teacherEmail": "teacher.name@university.edu"
        }
      ]
      If the document is empty or no schedule data can be found, return an empty array [].
      Do not include any other text, explanations, or markdown formatting around the JSON array.
    `;
    
    const pdfPart = fileToGenerativePart(pdfBuffer, mimeType);
    const result = await model.generateContent([prompt, pdfPart]);
    const response = await result.response;
    const text = response.text();
    const jsonString = text.replace(/```json/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonString);
  } catch (error) {
    console.error("Error calling Gemini API for timetable extraction:", error);
    throw new Error("Failed to extract timetable from PDF via Gemini API.");
  }
}

module.exports = { extractInfoFromPdf, extractTimetableFromPdf };