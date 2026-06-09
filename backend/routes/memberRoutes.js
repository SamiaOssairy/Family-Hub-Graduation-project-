const express = require('express');
const { createMember, getAllMembers, deleteMember, getUpcomingBirthdays } = require('../controllers/MemberController');
const { protect, restrictTo } = require('../controllers/AuthController');

const memberRouter = express.Router();

// Birthdays must be registered before '/:memberId'-style routes (none here, but safe ordering)
memberRouter.get('/birthdays', protect, getUpcomingBirthdays);
memberRouter.get('/', protect, getAllMembers);
memberRouter.post('/', protect, restrictTo('Parent'), createMember);
memberRouter.delete('/:memberId', protect, restrictTo('Parent'), deleteMember);

module.exports = memberRouter;











