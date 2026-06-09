
const mongoose = require('mongoose');
const validator = require('validator');
const bcrypt = require('bcrypt');

const memberSchema = new mongoose.Schema({
  username: {
    type: String,
    required: [true, 'Please provide your username'],
  },
  mail:{
    type: String,
    required: [true, 'Please provide your email'],
    lowercase: true,
    trim: true,
    validate: [validator.isEmail, 'Please provide a valid email']
  },
  password: {
    type: String,
    select: false, // Don't return password by default
    default: null  // null means user hasn't set their own password yet
  },
  isFirstLogin: {
    type: Boolean,
    default: true  // true until they set their own password
  },
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  },
  member_type_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MemberType',
    required: [true, 'Please provide a member type ID']
  },
  birth_date: {
    type: Date,
    required: [true, 'Please provide your birth date']
  }
});

// Hash the password before saving (only if password is modified)
memberSchema.pre("save", async function () {
  if (!this.isModified("password") || !this.password) return;
  this.password = await bcrypt.hash(this.password, 12);
});

// Check if the provided password is correct
memberSchema.methods.correctPassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Create compound index: username must be unique per family
memberSchema.index({ username: 1, family_id: 1 }, { unique: true });

// Create compound index: member email must be unique per family
memberSchema.index({ mail: 1, family_id: 1 }, { unique: true });

const Member = mongoose.model('Member', memberSchema);

module.exports = Member;














