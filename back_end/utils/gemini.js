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
 * Extracts student information from a PDF list.
 * @param {Buffer} pdfBuffer The buffer of the PDF file.
 * @param {string} mimeType The MIME type of the PDF.
 * @returns {Promise<Array<object>>} A promise resolving to an array of student objects.
 */
async function extractInfoFromPdf(pdfBuffer, mimeType) {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash-latest" });

    // --- PROMPT UPDATED FOR A LIST FORMAT ---
    const prompt = `
      From the provided PDF document, which contains a list of students, extract the following information for each student:
      1. Full Name (as "name")
      2. Roll Number or Student ID (as "rollNo")
      3. Email Address (as "email")

      Please return the information ONLY in a valid JSON array format, where each object in the array represents one student.
      Example format:
      [
        {
          "name": "John Doe",
          "rollNo": "CB.EN.U4XYZ21001",
          "email": "john.doe@university.edu"
        },
        {
          "name": "Jane Smith",
          "rollNo": "CB.EN.U4ABC21002",
          "email": "jane.smith@university.edu"
        }
      ]
      If the document is empty or no student data can be found, return an empty array [].
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

module.exports = { extractInfoFromPdf };