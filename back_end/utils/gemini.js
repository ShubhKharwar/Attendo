const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize the Google Generative AI client with the API key from environment variables
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
 * Extracts student information from an image containing multiple IDs using the Gemini Vision model.
 * @param {Buffer} imageBuffer The buffer of the image file.
 * @param {string} mimeType The MIME type of the image.
 * @returns {Promise<Array<object>>} A promise that resolves to an array of objects with extracted data.
 */
async function extractInfoFromImage(imageBuffer, mimeType) {
  try {
    // For text-and-image input, use the gemini-pro-vision model
    const model = genAI.getGenerativeModel({ model: "gemini-pro-vision" });

    const prompt = `
      From the provided image, identify all student ID cards and extract the following information for each one:
      1. Full Name (as "name")
      2. Roll Number or Student ID (as "rollNo")
      3. Email Address (as "email")
      4. College or University Name (as "college")

      Please return the information ONLY in a valid JSON array format, where each object in the array represents one student.
      Example format:
      [
        {
          "name": "John Doe",
          "rollNo": "CB.EN.U4XYZ21001",
          "email": "john.doe@university.edu",
          "college": "State University of Technology"
        },
        {
          "name": "Jane Smith",
          "rollNo": "CB.EN.U4ABC21002",
          "email": "jane.smith@university.edu",
          "college": "State University of Technology"
        }
      ]
      If no ID cards are found, return an empty array [].
      Do not include any other text, explanations, or markdown formatting around the JSON array.
    `;
    
    // Convert the image buffer to the format required by the Gemini API
    const imagePart = fileToGenerativePart(imageBuffer, mimeType);

    // Generate content using the model with the prompt and image
    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const text = response.text();
    
    // Clean up the response text to ensure it's a valid JSON string
    const jsonString = text.replace(/```json/g, "").replace(/```/g, "").trim();
    
    // Parse the JSON string into an object
    return JSON.parse(jsonString);

  } catch (error) {
    console.error("Error calling Gemini API:", error);
    throw new Error("Failed to extract information from image via Gemini API.");
  }
}

module.exports = { extractInfoFromImage };

