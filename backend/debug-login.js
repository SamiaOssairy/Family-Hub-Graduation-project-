require('dotenv').config();
const mongoose = require('mongoose');
const memberModel = require('./models/MemberModel');
const familyAccountModel = require('./models/FamilyAccountModel');
const memberTypeModel = require('./models/MemberTypeModel');
const bcrypt = require('bcrypt');

const email = 'menna_sherif77@icloud.com';
const password = '123';

// Build connection string the same way server.js does
const dbAtlasString = process.env.DB.replace(
  '<db_password>',
  process.env.DB_PASSWORD
);

async function debugLogin() {
  try {
    console.log('🔍 Connecting to database...');
    await mongoose.connect(dbAtlasString);
    console.log('✅ Connected!\n');

    console.log(`📧 Looking for member with email: ${email}`);
    
    // Find member
    const members = await memberModel.find({ mail: email })
      .select('+password')
      .populate('family_id', 'Title isActivated active password')
      .populate('member_type_id', 'type');

    if (!members || members.length === 0) {
      console.log('❌ NO MEMBER FOUND WITH THIS EMAIL!');
      await mongoose.connection.close();
      return;
    }

    console.log(`✅ Found ${members.length} member(s)\n`);

    for (let i = 0; i < members.length; i++) {
      const member = members[i];
      console.log(`\n--- Member ${i + 1} ---`);
      console.log('Username:', member.username);
      console.log('Email:', member.mail);
      console.log('Member Type:', member.member_type_id?.type);
      console.log('Family ID:', member.family_id?._id);
      console.log('Family Title:', member.family_id?.Title);
      console.log('Family Activated:', member.family_id?.isActivated);
      console.log('Family Active:', member.family_id?.active);
      console.log('Member Password Exists:', !!member.password);
      console.log('Is Parent:', member.member_type_id?.type === 'Parent');

      // Get family account with password
      if (member.family_id) {
        const familyAccount = await familyAccountModel.findById(member.family_id._id).select('+password');
        console.log('Family Password Hash:', familyAccount?.password ? familyAccount.password.substring(0, 20) + '...' : 'NO PASSWORD');

        // Test password
        if (familyAccount?.password) {
          const isMatch = await bcrypt.compare(password, familyAccount.password);
          console.log(`🔑 Testing password "${password}": ${isMatch ? '✅ CORRECT!' : '❌ WRONG!'}`);
        }
      }
    }

    await mongoose.connection.close();
    console.log('\n✅ Debug complete!');
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

debugLogin();
