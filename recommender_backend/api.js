import axios from 'axios';
// Configure base URL - works with Vite proxy in development
const API_BASE_URL = import.meta.env.PROD 
  ? 'https://your-render-backend-url.onrender.com'  // Replace with your actual Render URL
  : 'http://localhost:8000';


console.log('API_BASE_URL:', API_BASE_URL); 
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for debugging
api.interceptors.request.use(
  (config) => {
    console.log('API Request:', config.method?.toUpperCase(), config.url);
    return config;
  },
  (error) => {
    console.error('API Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => {
    console.log('API Response:', response.status, response.config.url);
    return response;
  },
  (error) => {
    console.error('API Response Error:', error.response?.status, error.response?.data);
    return Promise.reject(error);
  }
);

// ==================== API FUNCTIONS ====================

export const getRecommendations = async (request) => {
  try {
    const response = await api.post('/recommendations/', request);
    return response.data;
  } catch (error) {
    console.error('Error getting recommendations:', error);
    throw error;
  }
};

export const loadSampleData = async () => {
  try {
    const response = await api.post('/sample-data/load');
    return response.data;
  } catch (error) {
    console.error('Error loading sample data:', error);
    throw error;
  }
};

export const getDemoRequest = async () => {
  try {
    const response = await api.get('/sample-data/demo-request');
    return response.data;
  } catch (error) {
    console.error('Error getting demo request:', error);
    throw error;
  }
};

export const getTaskAnalytics = async () => {
  try {
    const response = await api.get('/analytics/tasks');
    return response.data;
  } catch (error) {
    console.error('Error getting task analytics:', error);
    throw error;
  }
};

export const getTasks = async (skip = 0, limit = 100) => {
  try {
    const response = await api.get(`/tasks/?skip=${skip}&limit=${limit}`);
    return response.data;
  } catch (error) {
    console.error('Error getting tasks:', error);
    throw error;
  }
};

export const createTask = async (taskData) => {
  try {
    const response = await api.post('/tasks/', taskData);
    return response.data;
  } catch (error) {
    console.error('Error creating task:', error);
    throw error;
  }
};

export const createUserProfile = async (userData) => {
  try {
    const response = await api.post('/users/', userData);
    return response.data;
  } catch (error) {
    console.error('Error creating user profile:', error);
    throw error;
  }
};

export const healthCheck = async () => {
  try {
    const response = await api.get('/health');
    return response.data;
  } catch (error) {
    console.error('Error checking health:', error);
    throw error;
  }
};

export const debugRecommendations = async (request) => {
  try {
    const response = await api.post('/recommendations/debug', request);
    return response.data;
  } catch (error) {
    console.error('Error debugging recommendations:', error);
    throw error;
  }
};

export default api;