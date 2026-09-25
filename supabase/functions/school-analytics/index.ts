import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    // Get the current user
    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error("Unauthorized");
    }

    // Verify user has school admin access
    const { data: profile } = await supabaseClient
      .from("profiles")
      .select("role, school_id")
      .eq("id", user.id)
      .single();

    if (
      !profile ||
      (profile.role !== "teacher" && profile.role !== "school_admin") ||
      !profile.school_id
    ) {
      throw new Error("Unauthorized: User does not have school admin access");
    }

    const { action, school_id, month_key, user_id, months } = await req.json();

    // Verify the requested school_id matches user's school
    if (school_id && school_id !== profile.school_id) {
      throw new Error("Unauthorized: Cannot access other school's data");
    }

    const schoolId = school_id || profile.school_id;

    switch (action) {
      case "get_school_overview":
        return await getSchoolOverview(supabaseClient, schoolId);

      case "get_monthly_leaderboard":
        return await getMonthlyLeaderboard(supabaseClient, schoolId, month_key);

      case "get_student_performance":
        return await getStudentPerformance(supabaseClient, user_id, schoolId);

      case "get_school_trends":
        return await getSchoolTrends(supabaseClient, schoolId, months || 6);

      case "get_all_students":
        return await getAllStudents(supabaseClient, schoolId);

      case "get_students_at_risk":
        return await getStudentsAtRisk(supabaseClient, schoolId);

      case "get_available_months":
        return await getAvailableMonths(supabaseClient, schoolId);

      default:
        throw new Error("Invalid action");
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});

async function getSchoolOverview(supabaseClient: any, schoolId: string) {
  // Get school info
  const { data: school } = await supabaseClient
    .from("schools")
    .select("name")
    .eq("id", schoolId)
    .single();

  // Get total students
  const { count: totalStudents } = await supabaseClient
    .from("profiles")
    .select("*", { count: "exact", head: true })
    .eq("school_id", schoolId);

  // Get active students (monthly_xp > 0)
  const { count: activeStudents } = await supabaseClient
    .from("profiles")
    .select("*", { count: "exact", head: true })
    .eq("school_id", schoolId)
    .gt("monthly_xp", 0);

  // Get aggregated stats
  const { data: stats } = await supabaseClient
    .from("profiles")
    .select("xp, monthly_xp, coins")
    .eq("school_id", schoolId);

  const totalXp = stats?.reduce((sum: number, s: any) => sum + (s.xp || 0), 0) || 0;
  const monthlyXp = stats?.reduce((sum: number, s: any) => sum + (s.monthly_xp || 0), 0) || 0;

  // Get courses completed
  const { count: totalCoursesCompleted } = await supabaseClient
    .from("user_course_progress")
    .select("*", { count: "exact", head: true })
    .eq("completed", true)
    .in(
      "user_id",
      supabaseClient
        .from("profiles")
        .select("id")
        .eq("school_id", schoolId)
    );

  // Get badges earned
  const { count: totalBadgesEarned } = await supabaseClient
    .from("user_badges")
    .select("*", { count: "exact", head: true })
    .in(
      "user_id",
      supabaseClient
        .from("profiles")
        .select("id")
        .eq("school_id", schoolId)
    );

  // Get gratitude entries
  const { count: totalGratitudeEntries } = await supabaseClient
    .from("gratitude_entries")
    .select("*", { count: "exact", head: true })
    .in(
      "user_id",
      supabaseClient
        .from("profiles")
        .select("id")
        .eq("school_id", schoolId)
    );

  // Get challenges completed
  const { count: totalChallengesCompleted } = await supabaseClient
    .from("user_challenges")
    .select("*", { count: "exact", head: true })
    .eq("is_completed", true)
    .in(
      "user_id",
      supabaseClient
        .from("profiles")
        .select("id")
        .eq("school_id", schoolId)
    );

  const engagementRate = totalStudents > 0 ? (activeStudents / totalStudents) * 100 : 0;

  const result = {
    school_id: schoolId,
    school_name: school?.name || "Unknown School",
    total_students: totalStudents || 0,
    active_students: activeStudents || 0,
    total_xp: totalXp,
    monthly_xp: monthlyXp,
    total_courses_completed: totalCoursesCompleted || 0,
    total_badges_earned: totalBadgesEarned || 0,
    total_gratitude_entries: totalGratitudeEntries || 0,
    total_challenges_completed: totalChallengesCompleted || 0,
    engagement_rate: engagementRate,
    generated_at: new Date().toISOString(),
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getMonthlyLeaderboard(
  supabaseClient: any,
  schoolId: string,
  monthKey: string
) {
  // Calculate XP for the specified month
  const [year, month] = monthKey.split("-");
  const startDate = `${year}-${month}-01`;
  const endDate = new Date(parseInt(year), parseInt(month), 0).toISOString().split("T")[0];

  // Get students with their March activity
  const { data: students } = await supabaseClient.rpc("get_school_monthly_leaderboard", {
    p_school_id: schoolId,
    p_start_date: startDate,
    p_end_date: endDate,
  });

  const topStudents = (students || []).slice(0, 20).map((s: any, index: number) => ({
    user_id: s.user_id,
    name: s.name,
    avatar_url: s.avatar_url,
    total_xp: s.total_xp || 0,
    monthly_xp: s.monthly_xp || 0,
    coins: parseFloat(s.coins || 0),
    courses_completed: s.courses_completed || 0,
    badges_earned: s.badges_earned || 0,
    challenges_completed: s.challenges_completed || 0,
    gratitude_entries: s.gratitude_entries || 0,
    goals_completed: s.goals_completed || 0,
    rank: index + 1,
    last_active: s.last_active,
  }));

  const result = {
    month_key: monthKey,
    school_id: schoolId,
    top_students: topStudents,
    generated_at: new Date().toISOString(),
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getStudentPerformance(
  supabaseClient: any,
  userId: string,
  schoolId: string
) {
  // Verify student belongs to the school
  const { data: student } = await supabaseClient
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .eq("school_id", schoolId)
    .single();

  if (!student) {
    throw new Error("Student not found in this school");
  }

  // Get detailed stats
  const { count: coursesCompleted } = await supabaseClient
    .from("user_course_progress")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("completed", true);

  const { count: badgesEarned } = await supabaseClient
    .from("user_badges")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId);

  const { count: challengesCompleted } = await supabaseClient
    .from("user_challenges")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("is_completed", true);

  const { count: gratitudeEntries } = await supabaseClient
    .from("gratitude_entries")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId);

  const { count: goalsCompleted } = await supabaseClient
    .from("goal_completions")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId);

  const result = {
    user_id: userId,
    name: student.name,
    avatar_url: student.avatar_url,
    total_xp: student.xp || 0,
    monthly_xp: student.monthly_xp || 0,
    coins: parseFloat(student.coins || 0),
    courses_completed: coursesCompleted || 0,
    badges_earned: badgesEarned || 0,
    challenges_completed: challengesCompleted || 0,
    gratitude_entries: gratitudeEntries || 0,
    goals_completed: goalsCompleted || 0,
    rank: 0,
    last_active: student.updated_at,
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getSchoolTrends(
  supabaseClient: any,
  schoolId: string,
  months: number
) {
  // This would require historical data tracking
  // For now, return empty trends
  const result = {
    school_id: schoolId,
    monthly_xp_trend: {},
    monthly_active_students: {},
    monthly_course_completions: {},
    generated_at: new Date().toISOString(),
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getAllStudents(supabaseClient: any, schoolId: string) {
  const { data: students } = await supabaseClient
    .from("profiles")
    .select("id, name, avatar_url, xp, monthly_xp, coins, updated_at")
    .eq("school_id", schoolId)
    .order("xp", { ascending: false });

  const studentsWithStats = await Promise.all(
    (students || []).map(async (student: any, index: number) => {
      const { count: coursesCompleted } = await supabaseClient
        .from("user_course_progress")
        .select("*", { count: "exact", head: true })
        .eq("user_id", student.id)
        .eq("completed", true);

      const { count: badgesEarned } = await supabaseClient
        .from("user_badges")
        .select("*", { count: "exact", head: true })
        .eq("user_id", student.id);

      return {
        user_id: student.id,
        name: student.name,
        avatar_url: student.avatar_url,
        total_xp: student.xp || 0,
        monthly_xp: student.monthly_xp || 0,
        coins: parseFloat(student.coins || 0),
        courses_completed: coursesCompleted || 0,
        badges_earned: badgesEarned || 0,
        challenges_completed: 0,
        gratitude_entries: 0,
        goals_completed: 0,
        rank: index + 1,
        last_active: student.updated_at,
      };
    })
  );

  const result = {
    students: studentsWithStats,
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getStudentsAtRisk(supabaseClient: any, schoolId: string) {
  // Students with monthly_xp = 0 or very low activity
  const { data: students } = await supabaseClient
    .from("profiles")
    .select("id, name, avatar_url, xp, monthly_xp, coins, updated_at")
    .eq("school_id", schoolId)
    .eq("monthly_xp", 0)
    .order("xp", { ascending: true })
    .limit(20);

  const studentsWithStats = (students || []).map((student: any, index: number) => ({
    user_id: student.id,
    name: student.name,
    avatar_url: student.avatar_url,
    total_xp: student.xp || 0,
    monthly_xp: student.monthly_xp || 0,
    coins: parseFloat(student.coins || 0),
    courses_completed: 0,
    badges_earned: 0,
    challenges_completed: 0,
    gratitude_entries: 0,
    goals_completed: 0,
    rank: index + 1,
    last_active: student.updated_at,
  }));

  const result = {
    students: studentsWithStats,
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getAvailableMonths(supabaseClient: any, schoolId: string) {
  // Generate last 12 months
  const months = [];
  const now = new Date();
  for (let i = 0; i < 12; i++) {
    const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const monthKey = `${date.getFullYear()}-${(date.getMonth() + 1)
      .toString()
      .padStart(2, "0")}`;
    months.push(monthKey);
  }

  const result = {
    months,
  };

  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
