const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const member = require("../models/MemberModel");
const memberType=require ("../models/MemberTypeModel");
const memberTypeController=require("./MemberTypeController");
//========================================================================================

exports.createMember = catchAsync(async (req, res, next) => {
  const { username, birth_date, member_type } = req.body;
  const mail = (req.body.mail || '').trim().toLowerCase();

  // Validate required fields
  if (!mail || !username || !birth_date || !member_type) {
    return next(new AppError("Please provide all required fields: mail, username, birth_date, member_type", 400));
  }
  
  // Get the parent's family account from the protected middleware
  const family_id = req.familyAccount._id;
  
  // Check if mail already exists in this family
  const existingMemberByMail = await member.findOne({ mail, family_id });
  if (existingMemberByMail) {
    return next(new AppError("A member with this email already exists in your family", 400));
  }
  
  // Check if username already exists in this family (username is unique per family, not system-wide)
  const existingMemberByUsername = await member.findOne({ username, family_id });
  if (existingMemberByUsername) {
    return next(new AppError("A member with this username already exists in your family. Please choose a different username.", 400));
  }
  
  // Check if member type exists for this family, if not create it
  let memberTypeDoc = await memberType.findOne({ type: member_type, family_id });
  if (!memberTypeDoc) {
    memberTypeDoc = await memberType.create({ type: member_type, family_id });
  }
  
  // Create the new member
  const newMember = await member.create({
    username,
    mail,
    family_id,
    member_type_id: memberTypeDoc._id,
    birth_date,
  });
  
  // Auto-create Point Wallet and Wishlist for new member
  const PointWallet = require("../models/point_walletModel");
  const Wishlist = require("../models/wishlistModel");
  
  // Try to create wallet and wishlist, but don't fail if they already exist
  try {
    await PointWallet.create({
      member_mail: mail,
      family_id,
      total_points: 0
    });
  } catch (err) { 
    // Wallet might already exist, that's okay
    console.log("Note: PointWallet creation skipped:", err.message);
  }
  
  try {
    await Wishlist.create({
      member_mail: mail,
      family_id,
      title: `${username}'s Wishlist`
    });
  } catch (err) {
    // Wishlist might already exist, that's okay
    console.log("Note: Wishlist creation skipped:", err.message);
  }
  
  // Populate the response
  const populatedMember = await member.findById(newMember._id).populate('member_type_id');
  
  res.status(201).json({
    status: "success",
    data: { 
      member: populatedMember,
      message: `Member created successfully. They can login with email: ${mail} and the family account password.`
    },
  });
});
//========================================================================================
exports.getAllMembers = catchAsync(async (req, res, next) => {
  // Get members only from the authenticated user's family
  const family_id = req.familyAccount._id;
  
  const members = await member.find({ family_id })
    .populate('member_type_id');
  
  res.status(200).json({  
    status: "success",
    results: members.length,
    data: { members },
  });
});

//========================================================================================
// Upcoming birthdays for the family.
// Derived from each member's birth_date — no separate model needed.
// Query: ?days=N  (lookahead window, default 30). Use days=366 to list everyone.
exports.getUpcomingBirthdays = catchAsync(async (req, res, next) => {
  const family_id = req.familyAccount._id;

  // Clamp the window to a sane range (1..366 days)
  let windowDays = parseInt(req.query.days, 10);
  if (Number.isNaN(windowDays)) windowDays = 30;
  windowDays = Math.min(Math.max(windowDays, 1), 366);

  const members = await member.find({ family_id }).populate('member_type_id');

  // Work in whole days from "today" (local server time), ignoring the time component.
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const MS_PER_DAY = 24 * 60 * 60 * 1000;

  const upcoming = members
    .filter((m) => m.birth_date)
    .map((m) => {
      const dob = new Date(m.birth_date);
      const month = dob.getMonth();
      const day = dob.getDate();

      // Next occurrence of this month/day on/after today.
      let next = new Date(today.getFullYear(), month, day);
      if (next < today) {
        next = new Date(today.getFullYear() + 1, month, day);
      }

      const daysUntil = Math.round((next - today) / MS_PER_DAY);
      const turningAge = next.getFullYear() - dob.getFullYear();

      return {
        member_id: m._id,
        username: m.username,
        mail: m.mail,
        memberType: m.member_type_id?.type || null,
        birth_date: m.birth_date,
        next_birthday: next,
        days_until: daysUntil,
        turning_age: turningAge,
        is_today: daysUntil === 0,
      };
    })
    .filter((b) => b.days_until <= windowDays)
    .sort((a, b) => a.days_until - b.days_until);

  res.status(200).json({
    status: "success",
    results: upcoming.length,
    data: { window_days: windowDays, birthdays: upcoming },
  });
});

//========================================================================================
// Delete a member from the family (Parent only)
exports.deleteMember = catchAsync(async (req, res, next) => {
  const { memberId } = req.params;
  const family_id = req.familyAccount._id;
  
  // Find the member to delete
  const memberToDelete = await member.findOne({ _id: memberId, family_id })
    .populate('member_type_id');
  
  if (!memberToDelete) {
    return next(new AppError("Member not found in your family", 404));
  }
  
  // Prevent deleting yourself
  if (memberToDelete._id.toString() === req.memberId.toString()) {
    return next(new AppError("You cannot remove yourself from the family", 400));
  }
  
  // Prevent deleting the last Parent
  if (memberToDelete.member_type_id.type === 'Parent') {
    const parentCount = await member.countDocuments({
      family_id,
      member_type_id: memberToDelete.member_type_id._id
    });
    
    if (parentCount <= 1) {
      return next(new AppError("Cannot delete the last parent in the family", 400));
    }
  }
  
  const memberMail = memberToDelete.mail;
  
  // Delete associated data
  const PointWallet = require("../models/point_walletModel");
  const Wishlist = require("../models/wishlistModel");
  const PointHistory = require("../models/point_historyModel");
  const WishlistItem = require("../models/wishlist_itemModel");
  
  try {
    // Delete point wallet
    await PointWallet.deleteOne({ member_mail: memberMail, family_id });
    
    // Delete point history
    await PointHistory.deleteMany({ member_mail: memberMail, family_id });
    
    // Find and delete wishlist items, then wishlist
    const wishlist = await Wishlist.findOne({ member_mail: memberMail, family_id });
    if (wishlist) {
      await WishlistItem.deleteMany({ wishlist_id: wishlist._id });
      await Wishlist.deleteOne({ member_mail: memberMail, family_id });
    }
  } catch (err) {
    console.log("Note: Error cleaning up member data:", err.message);
  }
  
  // Delete the member
  await member.findByIdAndDelete(memberId);
  
  res.status(200).json({
    status: "success",
    message: `Member ${memberToDelete.username} has been removed from the family`
  });
});



// get member info 






