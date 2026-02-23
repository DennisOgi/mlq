#!/usr/bin/env python3
"""
Wellspring College Student Bulk Import Script
Imports students from JSS1.csv and student_credentials_clean.csv
"""

import csv
import requests
import time
import json
from typing import Dict, List, Tuple

# Supabase Configuration
SUPABASE_URL = "https://hcvyumbkonrisrxbjnst.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjdnl1bWJrb25yaXNyeGJqbnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0NTcyOTIsImV4cCI6MjA2NzAzMzI5Mn0.6OS27VWKITYjfF5aKg7BMqxYu2wphh24O26J2-NMoew"
SCHOOL_ID = "3b93f5ca-3389-4285-8bb2-4248981eefe3"
SCHOOL_NAME = "Wellspring College"

# Statistics
success_count = 0
failure_count = 0
errors = []

def create_auth_user(email: str, password: str, full_name: str) -> Tuple[bool, str, str]:
    """Create a Supabase auth user"""
    url = f"{SUPABASE_URL}/auth/v1/signup"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json"
    }
    data = {
        "email": email,
        "password": password,
        "data": {
            "full_name": full_name
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        
        if response.status_code in [200, 201]:
            result = response.json()
            user_id = result.get('user', {}).get('id')
            if user_id:
                return True, user_id, ""
            else:
                return False, "", "No user ID in response"
        else:
            error_msg = response.json().get('msg', response.text)
            return False, "", f"Auth error: {error_msg}"
    except Exception as e:
        return False, "", f"Exception: {str(e)}"

def create_profile(user_id: str, name: str, school_id: str, school_name: str) -> Tuple[bool, str]:
    """Create a profile for the user"""
    url = f"{SUPABASE_URL}/rest/v1/profiles"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    data = {
        "id": user_id,
        "name": name,
        "school_id": school_id,
        "school_name": school_name,
        "xp": 0,
        "coins": 100,
        "is_premium": False
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        
        if response.status_code in [200, 201]:
            return True, ""
        else:
            error_msg = response.json().get('message', response.text)
            return False, f"Profile error: {error_msg}"
    except Exception as e:
        return False, f"Exception: {str(e)}"

def import_student(email: str, password: str, full_name: str, grade: str = None) -> bool:
    """Import a single student"""
    global success_count, failure_count, errors
    
    print(f"\n📝 Creating: {email}")
    print(f"   Name: {full_name}")
    print(f"   Grade: {grade or 'Not specified'}")
    
    # Create auth user
    success, user_id, error = create_auth_user(email, password, full_name)
    if not success:
        failure_count += 1
        error_msg = f"Failed to create {email}: {error}"
        print(f"   ❌ {error}")
        errors.append(error_msg)
        return False
    
    print(f"   ✅ Auth user created: {user_id}")
    
    # Small delay
    time.sleep(0.3)
    
    # Create profile
    success, error = create_profile(user_id, full_name, SCHOOL_ID, SCHOOL_NAME)
    if not success:
        failure_count += 1
        error_msg = f"Failed to create profile for {email}: {error}"
        print(f"   ❌ {error}")
        errors.append(error_msg)
        return False
    
    print(f"   ✅ Profile created")
    success_count += 1
    
    # Delay to avoid rate limiting
    time.sleep(0.5)
    
    return True

def import_jss1_csv(filepath: str, test_mode: bool = False, limit: int = 5):
    """Import students from JSS1.csv"""
    print(f"\n📚 Importing from: {filepath}")
    if test_mode:
        print(f"   🧪 TEST MODE: Only importing first {limit} students")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            count = 0
            
            for row in reader:
                if test_mode and count >= limit:
                    break
                
                first_name = row['First Name'].strip()
                last_name = row['Last Name'].strip()
                email = row['Email Address'].strip().lower()
                password = row['Password'].strip()
                
                if not email or not password:
                    continue
                
                full_name = f"{first_name} {last_name}"
                import_student(email, password, full_name, "JSS1")
                count += 1
        
        print(f"✅ Processed {count} students from JSS1.csv")
    except Exception as e:
        print(f"❌ Error reading JSS1.csv: {e}")
        errors.append(f"JSS1 CSV error: {e}")

def import_clean_csv(filepath: str, test_mode: bool = False, limit: int = 5):
    """Import students from student_credentials_clean.csv"""
    print(f"\n📚 Importing from: {filepath}")
    if test_mode:
        print(f"   🧪 TEST MODE: Only importing first {limit} students")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            count = 0
            
            for row in reader:
                if test_mode and count >= limit:
                    break
                
                full_name = row['Name'].strip()
                email = row['Email'].strip().lower()
                password = row['Password'].strip()
                
                if not email or not password:
                    continue
                
                import_student(email, password, full_name, None)
                count += 1
        
        print(f"✅ Processed {count} students from clean CSV")
    except Exception as e:
        print(f"❌ Error reading clean CSV: {e}")
        errors.append(f"Clean CSV error: {e}")

def print_statistics():
    """Print final statistics"""
    print("\n" + "=" * 60)
    print("📊 IMPORT STATISTICS")
    print("=" * 60)
    print(f"✅ Successful imports: {success_count}")
    print(f"❌ Failed imports: {failure_count}")
    print(f"📝 Total processed: {success_count + failure_count}")
    
    if errors:
        print(f"\n⚠️  ERRORS ({len(errors)}):")
        for error in errors[:10]:  # Show first 10 errors
            print(f"  - {error}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more errors")
    
    print("=" * 60 + "\n")

def main():
    """Main execution"""
    print("🚀 Wellspring College Student Import Script")
    print("=" * 60)
    
    # Ask user for mode
    print("\nSelect import mode:")
    print("1. Test mode (5 students from JSS1)")
    print("2. Full import (all 183 students)")
    
    choice = input("\nEnter choice (1 or 2): ").strip()
    
    if choice == "1":
        # Test mode
        print("\n🧪 TEST MODE SELECTED")
        import_jss1_csv('../JSS1.csv', test_mode=True, limit=5)
    elif choice == "2":
        # Full import
        print("\n🚀 FULL IMPORT SELECTED")
        confirm = input("This will import 183 students. Continue? (yes/no): ").strip().lower()
        if confirm == "yes":
            import_jss1_csv('../JSS1.csv', test_mode=False)
            import_clean_csv('../student_credentials_clean.csv', test_mode=False)
        else:
            print("Import cancelled.")
            return
    else:
        print("Invalid choice. Exiting.")
        return
    
    print_statistics()
    
    if success_count > 0:
        print("✅ Import completed successfully!")
    else:
        print("❌ Import failed. Please check errors above.")

if __name__ == "__main__":
    main()
