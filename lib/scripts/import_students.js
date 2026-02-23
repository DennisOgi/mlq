#!/usr/bin/env node
/**
 * Wellspring College Student Bulk Import Script
 * Imports students from JSS1.csv and student_credentials_clean.csv
 */

const fs = require('fs');
const https = require('https');
const readline = require('readline');

// Supabase Configuration
const SUPABASE_URL = "https://hcvyumbkonrisrxbjnst.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjdnl1bWJrb25yaXNyeGJqbnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0NTcyOTIsImV4cCI6MjA2NzAzMzI5Mn0.6OS27VWKITYjfF5aKg7BMqxYu2wphh24O26J2-NMoew";
const SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjdnl1bWJrb25yaXNyeGJqbnN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTQ1NzI5MiwiZXhwIjoyMDY3MDMzMjkyfQ.VsoNUEhD75MOnSg5q_HKaRQ64LDapKcEbuk7vixd4mk";
const SCHOOL_ID = "3b93f5ca-3389-4285-8bb2-4248981eefe3";
const SCHOOL_NAME = "Wellspring College";

// Statistics
let successCount = 0;
let failureCount = 0;
const errors = [];

// Helper function to make HTTP requests
function makeRequest(url, options, data = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const result = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, data: result });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

// Create auth user
async function createAuthUser(email, password, fullName) {
  const url = `${SUPABASE_URL}/auth/v1/signup`;
  const options = {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json'
    }
  };
  
  const data = {
    email,
    password,
    data: { full_name: fullName }
  };
  
  try {
    const response = await makeRequest(url, options, data);
    
    if (response.status === 200 || response.status === 201) {
      const userId = response.data.user?.id;
      if (userId) {
        return { success: true, userId, error: null };
      }
      return { success: false, userId: null, error: 'No user ID in response' };
    }
    
    const errorMsg = response.data.msg || response.data.message || JSON.stringify(response.data);
    return { success: false, userId: null, error: `Auth error: ${errorMsg}` };
  } catch (e) {
    return { success: false, userId: null, error: `Exception: ${e.message}` };
  }
}

// Create profile (using service role key to bypass RLS)
async function createProfile(userId, name, schoolId, schoolName) {
  const url = `${SUPABASE_URL}/rest/v1/profiles`;
  const options = {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal'
    }
  };
  
  const data = {
    id: userId,
    name,
    school_id: schoolId,
    school_name: schoolName,
    xp: 0,
    coins: 100,
    is_premium: false
  };
  
  try {
    const response = await makeRequest(url, options, data);
    
    if (response.status === 200 || response.status === 201) {
      return { success: true, error: null };
    }
    
    const errorMsg = response.data.message || JSON.stringify(response.data);
    return { success: false, error: `Profile error: ${errorMsg}` };
  } catch (e) {
    return { success: false, error: `Exception: ${e.message}` };
  }
}

// Import a single student
async function importStudent(email, password, fullName, grade = null) {
  console.log(`\n📝 Creating: ${email}`);
  console.log(`   Name: ${fullName}`);
  console.log(`   Grade: ${grade || 'Not specified'}`);
  
  let userId = null;
  
  // Create auth user
  const authResult = await createAuthUser(email, password, fullName);
  if (!authResult.success) {
    // Check if user already exists
    if (authResult.error.includes('already registered')) {
      console.log(`   ⚠️  User already exists, skipping to next...`);
      failureCount++;
      errors.push(`Skipped ${email}: User already registered`);
      return false;
    }
    
    failureCount++;
    const errorMsg = `Failed to create ${email}: ${authResult.error}`;
    console.log(`   ❌ ${authResult.error}`);
    errors.push(errorMsg);
    return false;
  }
  
  userId = authResult.userId;
  console.log(`   ✅ Auth user created: ${userId}`);
  
  // Small delay
  await new Promise(resolve => setTimeout(resolve, 300));
  
  // Create profile
  const profileResult = await createProfile(userId, fullName, SCHOOL_ID, SCHOOL_NAME);
  if (!profileResult.success) {
    failureCount++;
    const errorMsg = `Failed to create profile for ${email}: ${profileResult.error}`;
    console.log(`   ❌ ${profileResult.error}`);
    errors.push(errorMsg);
    return false;
  }
  
  console.log(`   ✅ Profile created`);
  successCount++;
  
  // Delay to avoid rate limiting
  await new Promise(resolve => setTimeout(resolve, 500));
  
  return true;
}

// Parse CSV
function parseCSV(content) {
  const lines = content.split('\n').filter(line => line.trim());
  const headers = lines[0].split(',').map(h => h.trim());
  const rows = [];
  
  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',').map(v => v.trim());
    if (values.length === headers.length) {
      const row = {};
      headers.forEach((header, index) => {
        row[header] = values[index];
      });
      rows.push(row);
    }
  }
  
  return rows;
}

// Import from JSS1.csv
async function importJSS1(filepath, testMode = false, limit = 5) {
  console.log(`\n📚 Importing from: ${filepath}`);
  if (testMode) {
    console.log(`   🧪 TEST MODE: Only importing first ${limit} students`);
  }
  
  try {
    const content = fs.readFileSync(filepath, 'utf-8');
    const rows = parseCSV(content);
    
    let count = 0;
    for (const row of rows) {
      if (testMode && count >= limit) break;
      
      const firstName = row['First Name'];
      const lastName = row['Last Name'];
      const email = row['Email Address'].toLowerCase();
      const password = row['Password'];
      
      if (!email || !password) continue;
      
      const fullName = `${firstName} ${lastName}`;
      await importStudent(email, password, fullName, 'JSS1');
      count++;
    }
    
    console.log(`✅ Processed ${count} students from JSS1.csv`);
  } catch (e) {
    console.log(`❌ Error reading JSS1.csv: ${e.message}`);
    errors.push(`JSS1 CSV error: ${e.message}`);
  }
}

// Import from student_credentials_clean.csv
async function importClean(filepath, testMode = false, limit = 5) {
  console.log(`\n📚 Importing from: ${filepath}`);
  if (testMode) {
    console.log(`   🧪 TEST MODE: Only importing first ${limit} students`);
  }
  
  try {
    const content = fs.readFileSync(filepath, 'utf-8');
    const rows = parseCSV(content);
    
    let count = 0;
    for (const row of rows) {
      if (testMode && count >= limit) break;
      
      const fullName = row['Name'];
      const email = row['Email'].toLowerCase();
      const password = row['Password'];
      
      if (!email || !password) continue;
      
      await importStudent(email, password, fullName, null);
      count++;
    }
    
    console.log(`✅ Processed ${count} students from clean CSV`);
  } catch (e) {
    console.log(`❌ Error reading clean CSV: ${e.message}`);
    errors.push(`Clean CSV error: ${e.message}`);
  }
}

// Print statistics
function printStatistics() {
  console.log('\n' + '='.repeat(60));
  console.log('📊 IMPORT STATISTICS');
  console.log('='.repeat(60));
  console.log(`✅ Successful imports: ${successCount}`);
  console.log(`❌ Failed imports: ${failureCount}`);
  console.log(`📝 Total processed: ${successCount + failureCount}`);
  
  if (errors.length > 0) {
    console.log(`\n⚠️  ERRORS (${errors.length}):`);
    errors.slice(0, 10).forEach(error => {
      console.log(`  - ${error}`);
    });
    if (errors.length > 10) {
      console.log(`  ... and ${errors.length - 10} more errors`);
    }
  }
  
  console.log('='.repeat(60) + '\n');
}

// Main function
async function main() {
  console.log('🚀 Wellspring College Student Import Script');
  console.log('='.repeat(60));
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  console.log('\nSelect import mode:');
  console.log('1. Test mode (5 students from JSS1)');
  console.log('2. Full import (all 183 students)');
  
  rl.question('\nEnter choice (1 or 2): ', async (choice) => {
    if (choice.trim() === '1') {
      // Test mode
      console.log('\n🧪 TEST MODE SELECTED');
      await importJSS1('lib/JSS1.csv', true, 5);
    } else if (choice.trim() === '2') {
      // Full import
      console.log('\n🚀 FULL IMPORT SELECTED');
      rl.question('This will import 183 students. Continue? (yes/no): ', async (confirm) => {
        if (confirm.trim().toLowerCase() === 'yes') {
          await importJSS1('lib/JSS1.csv', false);
          await importClean('lib/student_credentials_clean.csv', false);
        } else {
          console.log('Import cancelled.');
        }
        
        printStatistics();
        
        if (successCount > 0) {
          console.log('✅ Import completed successfully!');
        } else {
          console.log('❌ Import failed. Please check errors above.');
        }
        
        rl.close();
      });
      return;
    } else {
      console.log('Invalid choice. Exiting.');
      rl.close();
      return;
    }
    
    printStatistics();
    
    if (successCount > 0) {
      console.log('✅ Import completed successfully!');
    } else {
      console.log('❌ Import failed. Please check errors above.');
    }
    
    rl.close();
  });
}

main().catch(console.error);
