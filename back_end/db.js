const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const SALT_WORK_FACTOR = 10;

// --- User Schema ---
const userSchema = new mongoose.Schema({
    // RECOMMENDATION: Add a name field to store the extracted name.
    // name: {
    //     type: String,
    //     required: [true, 'Name is required.'],
    //     trim: true
    // },
    rollNo: {
        type: String,
        required: [true, 'Roll Number is required.'],
        trim: true,
        unique: true
    },
    email: {
        type: String,
        required: [true, 'Email is required.'],
        trim: true,
        unique: true,
        lowercase: true,
        match: [/\S+@\S+\.\S+/, 'is invalid']
    },
    password: {
        type: String,
        required: [true, 'Password is required.']
    }
}, {
    timestamps: true
});

// Mongoose 'pre-save' hook to hash the password before saving
// (The duplicate hook has been removed for clarity and correctness)
userSchema.pre('save', async function(next) {
    if (!this.isModified('password')) return next();
    try {
        const salt = await bcrypt.genSalt(SALT_WORK_FACTOR);
        this.password = await bcrypt.hash(this.password, salt);
        next();
    } catch (err) {
        next(err);
    }
});

// Instance method to compare a candidate password with the stored hash
userSchema.methods.comparePassword = function(candidatePassword) {
    return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model('User', userSchema);

// --- Temporary Password Schema --- (No changes needed)
const temporaryPasswordSchema = new mongoose.Schema({
    rollNo: {
        type: String,
        required: true,
        unique: true,
        ref: 'User'
    },
    password: {
        type: String,
        required: true
    }
}, {
    timestamps: true
});

const TemporaryPassword = mongoose.model('TemporaryPassword', temporaryPasswordSchema);

// --- Database Connection --- (No changes needed)
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('MongoDB connected successfully.');
    } catch (error) {
        console.error('MongoDB connection failed:', error.message);
        process.exit(1);
    }
};

module.exports = { User, TemporaryPassword, connectDB };