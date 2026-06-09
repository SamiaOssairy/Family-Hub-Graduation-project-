

// signup ,login ,logout ,protect,restrictTo,resetPassword
const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const jwt = require("jsonwebtoken");
const familyAccountModel = require("../models/FamilyAccountModel");
const memberModel = require("../models/MemberModel");
const memberTypeModel = require("../models/MemberTypeModel");
const PointWallet = require("../models/point_walletModel");
const Wishlist = require("../models/wishlistModel");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const mongoose = require("mongoose");

//========================================================================================

// Get families linked to an email so user can choose which family to login to
exports.getFamiliesByMail = catchAsync(async (req, res, next) => {
  const mail = (req.query.mail || req.body.mail || '').trim().toLowerCase();

  if (!mail) {
    return next(new AppError("Please provide email", 400));
  }

  const members = await memberModel.find({ mail })
    .populate('family_id', 'Title isActivated active')
    .populate('member_type_id', 'type');

  const families = members
    .filter((m) => m.family_id)
    .map((m) => ({
      family_id: m.family_id._id,
      familyTitle: m.family_id.Title,
      isActivated: m.family_id.isActivated,
      isActive: m.family_id.active,
      member_id: m._id,
      username: m.username,
      memberType: m.member_type_id?.type || null,
    }));

  res.status(200).json({
    message: "success",
    data: {
      mail,
      families,
    },
  });
});

//========================================================================================

const signToken = (payload) => {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN,
  });
};

//========================================================================================

// Password policy: at least 8 characters, with one uppercase letter, one lowercase
// letter, one digit, and one special character.
const PASSWORD_RULE_MESSAGE =
  "Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number, and a special character";

const isStrongPassword = (password) => {
  const strong = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;
  return typeof password === "string" && strong.test(password);
};

//========================================================================================

// automatically add mail of parent to members when signing up
exports.signUp = catchAsync(async (req, res, next) => {
  const { mail, password, Title, username, birth_date } = req.body;
  
  // Validate required fields
  if (!mail || !password || !Title || !username || !birth_date) {
    return next(new AppError("Please provide all required fields: mail, password, Title, username, birth_date", 400));
  }

  // Enforce password strength policy
  if (!isStrongPassword(password)) {
    return next(new AppError(PASSWORD_RULE_MESSAGE, 400));
  }

  // Create the family account, its Parent member type, the parent member, and the
  // parent's point wallet + wishlist as a single ATOMIC unit. If any step fails,
  // the whole signup is rolled back so we never leave a half-created family
  // (e.g. a family account with no parent member, or a member with no wallet).
  const session = await mongoose.startSession();

  let newAccount, parentType, newMember;

  try {
    await session.withTransaction(async () => {
      // Step 1: Create family account first.
      // .create() with a session must be called with an array and returns an array.
      [newAccount] = await familyAccountModel.create([{
        mail,
        password,
        Title,
        isActivated: true,
      }], { session });

      // Step 2: Create "Parent" member type for this family
      [parentType] = await memberTypeModel.create([{
        type: "Parent",
        family_id: newAccount._id,
      }], { session });

      // Step 3: Create parent member (Parent already has password via family account, so isFirstLogin = false)
      [newMember] = await memberModel.create([{
        username,
        mail,
        family_id: newAccount._id,
        member_type_id: parentType._id,
        birth_date,
        isFirstLogin: false, // Parent uses family password, no need to set new password
      }], { session });

      // Step 4: Auto-create Point Wallet and Wishlist for parent.
      // These are now part of the transaction — if they fail, signup rolls back.
      await PointWallet.create([{
        member_mail: mail,
        family_id: newAccount._id,
        total_points: 0,
      }], { session });

      await Wishlist.create([{
        member_mail: mail,
        family_id: newAccount._id,
        title: `${username}'s Wishlist`,
      }], { session });
    });
  } finally {
    await session.endSession();
  }

  const token = signToken({ id: newAccount._id, member_id: newMember._id });
  
  res.status(201).json({
    message: "success",
    data: {
      familyId: newAccount._id,
      memberId: newMember._id,
      mail: newMember.mail,
      username: newMember.username,
      familyTitle: newAccount.Title,
      memberType: parentType.type,
      account: newAccount,
      member: newMember,
    },
    token,
  });
});

//========================================================================================

// go search for mails in members ,then check for the family he belong to (if it is activated or not )
// , then go to memberType to check for the type of this member
exports.login = catchAsync(async (req, res, next) => {
  const { password, family_id } = req.body;
  const mail = (req.body.mail || '').trim().toLowerCase();

  if (!mail || !password) {
    return next(new AppError("Please provide email and password", 400));
  }

  // Step 1: Resolve member by email and family
  let member;

  if (family_id) {
    if (!mongoose.Types.ObjectId.isValid(family_id)) {
      return next(new AppError("Invalid family ID", 400));
    }

    member = await memberModel.findOne({ mail, family_id })
      .select('+password')
      .populate('family_id')
      .populate('member_type_id');
  } else {
    const matchedMembers = await memberModel.find({ mail })
      .select('+password')
      .populate('family_id')
      .populate('member_type_id');

    if (matchedMembers.length > 1) {
      return res.status(409).json({
        message: "Multiple families found for this email. Please choose a family and try again.",
        data: {
          families: matchedMembers
            .filter((m) => m.family_id)
            .map((m) => ({
              family_id: m.family_id._id,
              familyTitle: m.family_id.Title,
              isActivated: m.family_id.isActivated,
              isActive: m.family_id.active,
              member_id: m._id,
              username: m.username,
              memberType: m.member_type_id?.type || null,
            })),
        },
      });
    }

    member = matchedMembers[0];
  }

  if (!member) {
    return next(new AppError("Incorrect email or password", 401));
  }

  // Step 2: Check if the family account is activated
  if (!member.family_id.isActivated) {
    return next(new AppError("This family account is not activated", 403));
  }

  // Step 3: Get the family account with password
  const familyAccount = await familyAccountModel.findById(member.family_id._id).select('+password');

  // Check if the family account is deactivated
  if (!familyAccount.active) {
    return next(new AppError("This account has been deactivated. Please contact support to reactivate.", 403));
  }

  // Step 4: Check password - either member's own password or family password
  let passwordCorrect = false;
  
  // Parents ALWAYS use family password and never need to change it
  const isParent = member.member_type_id.type === 'Parent';
  
  if (member.password && !isParent) {
    // Non-parent member has their own password - use it
    passwordCorrect = await member.correctPassword(password);
  } else {
    // Parent OR member without own password - use family account password
    passwordCorrect = await familyAccount.correctPassword(password);
  }

  if (!passwordCorrect) {
    return next(new AppError("Incorrect email or password", 401));
  }

  // Determine if first login (only for non-parents who haven't set password)
  const isFirstLogin = !isParent && member.isFirstLogin && !member.password;

  // Step 5: Generate token and return user info
  const token = signToken({ id: familyAccount._id, member_id: member._id });

  res.status(200).json({
    message: "success",
    data: {
      familyId: familyAccount._id,
      memberId: member._id,
      mail: member.mail,
      username: member.username,
      familyTitle: familyAccount.Title,
      memberType: member.member_type_id.type,
      isFirstLogin: isFirstLogin, // Only true for non-parents on first login
    },
    token,
  });
});

//========================================================================================

// Set password for first-time users or change existing password
exports.setPassword = catchAsync(async (req, res, next) => {
  const { currentPassword, newPassword, confirmPassword } = req.body;
  
  if (!newPassword || !confirmPassword) {
    return next(new AppError("Please provide new password and confirmation", 400));
  }
  
  if (newPassword !== confirmPassword) {
    return next(new AppError("Passwords do not match", 400));
  }
  
  // Enforce password strength policy
  if (!isStrongPassword(newPassword)) {
    return next(new AppError(PASSWORD_RULE_MESSAGE, 400));
  }
  
  // Get the member with password
  const member = await memberModel.findById(req.memberId).select('+password');
  
  if (!member) {
    return next(new AppError("Member not found", 404));
  }
  
  // If member already has a password, verify current password
  if (member.password && !member.isFirstLogin) {
    if (!currentPassword) {
      return next(new AppError("Please provide your current password", 400));
    }
    
    const isCorrect = await member.correctPassword(currentPassword);
    if (!isCorrect) {
      return next(new AppError("Current password is incorrect", 401));
    }
  }
  
  // Set new password and mark as not first login
  member.password = newPassword;
  member.isFirstLogin = false;
  await member.save();
  
  res.status(200).json({
    message: "success",
    data: {
      message: "Password updated successfully"
    }
  });
});

exports.protect = catchAsync(async (req, res, next) => {
  if (
    !req.headers.authorization ||
    !req.headers.authorization.startsWith("Bearer")
  ) {
    return next(
      new AppError("You are not logged in! please log in to get access", 401)
    );
  }
  
  const token = req.headers.authorization.split(" ")[1]; // Bearer token => [Bearer , token]
  const decode = await jwt.verify(token, process.env.JWT_SECRET);
  
  // Get the family account
  const familyAccount = await familyAccountModel.findById(decode.id);
  if (!familyAccount) {
    return next(new AppError("Family account no longer exists", 404));
  }

  // Check if the account is deactivated
  if (!familyAccount.active) {
    return next(new AppError("This account has been deactivated. Please contact support to reactivate.", 403));
  }
  
  // Get the member
  const member = await memberModel.findById(decode.member_id)
    .populate('member_type_id');
  
  if (!member) {
    return next(new AppError("Member no longer exists", 404));
  }
  
  // Attach family account, member_id, and member to request for later use
  req.familyAccount = familyAccount;
  req.memberId = decode.member_id;
  req.member = member;
  
  next();
});

//========================================================================================

exports.restrictTo = (...memberTypes) => {
  return catchAsync(async (req, res, next) => {
    // Find the specific member who is making the request
    const member = await memberModel.findById(req.memberId)
      .populate('member_type_id');
    
    if (!member) {
      return next(new AppError("Member not found", 404));
    }
    
    // Check if member type is allowed
    if (!memberTypes.includes(member.member_type_id.type)) {
      return next(
        new AppError("You do not have permission to perform this action", 403)
      );
    }
    
    // Attach member to request for later use
    req.member = member;
    next();
  });
};
//========================================================================================
// Forgot Password - generates and sends reset token
exports.forgotPassword = catchAsync(async (req, res, next) => {
  const mail = (req.body.mail || '').trim().toLowerCase();

  if (!mail) {
    return next(new AppError("Please provide your email address", 400));
  }

  // Step 1: Find family account by email
  const familyAccount = await familyAccountModel.findOne({ mail });
  
  if (!familyAccount) {
    return next(new AppError("No account found with that email address", 404));
  }

  // Step 2: Generate reset token
  const resetToken = familyAccount.createPasswordResetToken();
  await familyAccount.save({ validateBeforeSave: false });

  // Step 3: Create reset URL
  const resetURL = `${req.protocol}://${req.get('host')}/api/auth/resetPassword/${resetToken}`;

  // Step 4: Send email with reset link
  try {
    // Configure email transporter (using Gmail as example)
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USERNAME,
        pass: process.env.EMAIL_PASSWORD,
      },
    });

    const mailOptions = {
      from: process.env.EMAIL_USERNAME,
      to: mail,
      subject: 'Password Reset Request (Valid for 60 minutes)',
      text: `Forgot your password? Click this link to reset it: ${resetURL}\n\nIf you didn't request this, please ignore this email.`,
      html: `
        <h2>Password Reset Request</h2>
        <p>You requested a password reset. Click the link below to reset your password:</p>
        <a href="${resetURL}">Reset Password</a>
        <p>This link is valid for 60 minutes.</p>
        <p>If you didn't request this, please ignore this email.</p>
      `,
    };

    await transporter.sendMail(mailOptions);

    res.status(200).json({
      message: "success",
      data: {
        message: "Password reset link sent to your email",
      },
    });
  } catch (error) {
    // If email fails, reset the token fields
    familyAccount.passwordResetToken = undefined;
    familyAccount.passwordResetExpires = undefined;
    await familyAccount.save({ validateBeforeSave: false });

    return next(
      new AppError("There was an error sending the email. Please try again later.", 500)
    );
  }
});

//========================================================================================
// Reset Password - uses token to change password
exports.resetPassword = catchAsync(async (req, res, next) => {
  const { token } = req.params;
  const { password, passwordConfirm } = req.body;

  if (!password || !passwordConfirm) {
    return next(new AppError("Please provide password and password confirmation", 400));
  }

  if (password !== passwordConfirm) {
    return next(new AppError("Passwords do not match", 400));
  }

  // Enforce password strength policy
  if (!isStrongPassword(password)) {
    return next(new AppError(PASSWORD_RULE_MESSAGE, 400));
  }

  // Step 1: Hash the token from URL to compare with database
  const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

  // Step 2: Find family account by token and check if not expired
  const familyAccount = await familyAccountModel.findOne({
    passwordResetToken: hashedToken,
    passwordResetExpires: { $gt: Date.now() },
  }).select('+password');

  if (!familyAccount) {
    return next(new AppError("Token is invalid or has expired", 400));
  }

  // Step 3: Update password
  familyAccount.password = password;
  familyAccount.passwordResetToken = undefined;
  familyAccount.passwordResetExpires = undefined;
  await familyAccount.save();

  // Step 4: Generate new JWT token and log user in
  const jwtToken = signToken({ id: familyAccount._id });

  res.status(200).json({
    message: "success",
    data: {
      message: "Password reset successful",
    },
    token: jwtToken,
  });
});