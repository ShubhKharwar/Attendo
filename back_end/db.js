const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const SALT_WORK_FACTOR = 10; // The cost factor for hashing

// --- User Schema ---
// This structure holds the permanent student data.
const userSchema = new mongoose.Schema({
    rollNo: {
        type: String,
        required: [true, 'Roll Number is required.'],
        trim: true,
        unique: true
    },
    name:{
        type:String,
        required: true,
        trim:true
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
    },
    interests: {type:[String],default:[]},
    interestsSelected: { type: Boolean, default: false }

}, {
    timestamps: true
});

// Mongoose 'pre-save' hook to hash the password before saving
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


userSchema.pre('save', async function(next) {
    // Only hash the password if it has been modified (or is new)
    if (!this.isModified('password')) return next();

    try {
        // Hash the password along with our new salt
        this.password = await bcrypt.hash(this.password, salt);
        next();
    } catch (err) {
        next(err);
    }
});


const User = mongoose.model('User', userSchema);


// --- Temporary Password Schema ---
// This schema stores the auto-generated plain-text passwords for admins to view.
// WARNING: Storing plain-text passwords is a security risk. This model is for
// demonstration. In a production system, these should be securely handled and
// ideally deleted after the user's first login.
const temporaryPasswordSchema = new mongoose.Schema({
    rollNo: {
        type: String,
        required: true,
        unique: true,
        ref: 'User' // Links this temporary password to a user
    },
    password: {
        type: String,
        required: true
    }
}, {
    timestamps: true
});

const TemporaryPassword = mongoose.model('TemporaryPassword', temporaryPasswordSchema);


// --- Database Connection ---
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('MongoDB connected successfully.');
    } catch (error) {
        console.error('MongoDB connection failed:', error.message);
        process.exit(1);
    }
};

// Export all models and the connectDB function
module.exports = { User, TemporaryPassword, connectDB };