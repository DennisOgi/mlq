import 'package:my_leadership_quest/models/challenge_model.dart';

class ChallengeService {
  static final List<ChallengeModel> _premiumChallenges = [
    // Indomie Challenge
    ChallengeModel(
      id: 'indomie_1',
      title: 'Indomie Recipe Innovation',
      description: 'Create a unique and delicious recipe using Indomie noodles as the main ingredient. Share photos and instructions for your creation!',
      type: ChallengeType.premium,
      realWorldPrize: "A year's supply of Indomie products and N100,000 cash prize",
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 21)),
      organizationId: 'indomie',
      organizationName: 'Indomie Nigeria',
      organizationLogo: 'assets/images/indomie-logo.png',
      criteria: ['Creativity', 'Taste', 'Presentation', 'Nutritional Value'],
      timeline: '3 weeks',
      isTeamChallenge: false,
      coinReward: 150,
    ),
    // Kellogs Challenge
    ChallengeModel(
      id: 'kellogs_1',
      title: 'Breakfast Champions',
      description: 'Design a balanced breakfast meal plan for a week featuring Kellogg\'s cereals. Include nutritional information and benefits for young leaders.',
      type: ChallengeType.premium,
      realWorldPrize: "Kellogg's product hamper and N75,000 education voucher",
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 14)),
      organizationId: 'kellogs',
      organizationName: 'Kellogg\'s',
      organizationLogo: 'assets/images/kelloggs.png',
      criteria: ['Nutritional Balance', 'Creativity', 'Presentation', 'Educational Value'],
      timeline: '2 weeks',
      isTeamChallenge: false,
      coinReward: 120,
    ),
    ChallengeModel(
      id: 'apen_1',
      title: 'Innovative Lesson Plan',
      description: 'Create an engaging and interactive lesson plan for a specific subject that incorporates technology and critical thinking skills.',
      type: ChallengeType.premium,
      realWorldPrize: "A year's supply of educational resources or N500,000",
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 14)),
      organizationId: 'apen',
      organizationName: 'Association of Private Educators of Nigeria',
      organizationLogo: 'assets/images/sponsors/ASPEN-logo.jpg',
      criteria: ['Creativity', 'Effectiveness', 'Feasibility of the lesson plan'],
      timeline: '2 weeks',
      isTeamChallenge: false,
      coinReward: 100,
    ),
    ChallengeModel(
      id: 'google_1',
      title: 'Google Maps Mashup',
      description: 'Create an innovative web application or tool that utilizes Google Maps to solve a real-world problem or showcase local culture.',
      type: ChallengeType.premium,
      realWorldPrize: 'A Google Cloud Platform credit package or a Chromebook',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 28)),
      organizationId: 'google',
      organizationName: 'Google',
      organizationLogo: 'assets/images/sponsors/google.jpg',
      criteria: ['Originality', 'Functionality', 'Impact of the application'],
      timeline: '4 weeks',
      isTeamChallenge: true,
      coinReward: 150,
    ),
    ChallengeModel(
      id: 'microsoft_1',
      title: 'AI for Social Good',
      description: 'Develop an AI-powered solution that addresses a social or environmental issue.',
      type: ChallengeType.premium,
      realWorldPrize: 'A Microsoft Azure credit package or a Surface device',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 42)),
      organizationId: 'microsoft',
      organizationName: 'Microsoft',
      organizationLogo: 'assets/images/sponsors/microsoft.png',
      criteria: ['Impact', 'Innovation', 'Feasibility of the solution'],
      timeline: '6 weeks',
      isTeamChallenge: true,
      coinReward: 200,
    ),
    ChallengeModel(
      id: 'lego_1',
      title: 'Robotics for Social Impact',
      description: 'Design and build a robot that addresses a specific social or environmental challenge.',
      type: ChallengeType.premium,
      realWorldPrize: 'A LEGO Education robotics kit or a cash prize',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 56)),
      organizationId: 'lego',
      organizationName: 'LEGO Education',
      organizationLogo: 'assets/images/sponsors/LEGO_logo.png',
      criteria: ['Innovation', 'Functionality', 'Impact of the robot'],
      timeline: '6-8 weeks',
      isTeamChallenge: true,
      coinReward: 250,
    ),
    ChallengeModel(
      id: 'fmcg_1',
      title: 'Sustainable Packaging Design',
      description: 'Design an eco-friendly packaging solution for a specific product.',
      type: ChallengeType.premium,
      realWorldPrize: "N200,000 or a year's supply of the company's products",
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 21)),
      organizationId: 'fmcg',
      organizationName: 'FMCG Company',
      organizationLogo: 'assets/images/sponsors/fmcg.webp',
      criteria: ['Creativity', 'Sustainability', 'Feasibility of the design'],
      timeline: '3 weeks',
      isTeamChallenge: false,
      coinReward: 120,
    ),
    ChallengeModel(
      id: 'waec_1',
      title: "9 A's Challenge",
      description: 'Achieve 9 A\'s in the WAEC examination.',
      type: ChallengeType.premium,
      realWorldPrize: 'N1 million or a scholarship for further studies',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 180)),
      organizationId: 'waec',
      organizationName: 'West African Examinations Council',
      organizationLogo: 'assets/images/sponsors/Waec_logo.png',
      criteria: ['Actual examination results'],
      timeline: 'Register before the next WAEC examination session',
      isTeamChallenge: false,
      coinReward: 300,
    ),
    ChallengeModel(
      id: 'lagos_1',
      title: 'Smart City Solution',
      description: 'Develop an innovative solution that addresses a specific challenge facing Lagos State.',
      type: ChallengeType.premium,
      realWorldPrize: 'N5 million or a recognition award',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 56)),
      organizationId: 'lagos',
      organizationName: 'Lagos State Government',
      organizationLogo: 'assets/images/sponsors/lagosstategovernment.jpeg',
      criteria: ['Impact', 'Innovation', 'Feasibility of the solution'],
      timeline: '8 weeks',
      isTeamChallenge: true,
      coinReward: 500,
    ),
  ];

  // Get all premium challenges
  static List<ChallengeModel> getPremiumChallenges() {
    return _premiumChallenges;
  }

  // Get challenge by ID
  static ChallengeModel? getChallengeById(String id) {
    try {
      return _premiumChallenges.firstWhere((challenge) => challenge.id == id);
    } catch (e) {
      return null;
    }
  }

  // Mock secret access URLs for non-UUID premium challenges
  static const Map<String, String> _mockAccessUrls = {
    'indomie_1': 'https://example.com/indomie/secret-access',
    'kellogs_1': 'https://example.com/kelloggs/secret-access',
    'apen_1': 'https://example.com/apen/secret-access',
    'google_1': 'https://example.com/google/secret-access',
    'microsoft_1': 'https://example.com/microsoft/secret-access',
    'lego_1': 'https://example.com/lego/secret-access',
    'fmcg_1': 'https://example.com/fmcg/secret-access',
    'waec_1': 'https://example.com/waec/secret-access',
    'lagos_1': 'https://example.com/lagos/secret-access',
  };

  // Returns a mock access URL for a given mock challenge ID
  static String? getMockAccessUrl(String id) {
    return _mockAccessUrls[id] ?? 'https://example.com/premium/secret-access';
  }

  // Get challenges by organization
  static List<ChallengeModel> getChallengesByOrganization(String organizationId) {
    return _premiumChallenges
        .where((challenge) => challenge.organizationId == organizationId)
        .toList();
  }

  // Add new challenge (for admin use)
  static void addChallenge(ChallengeModel challenge) {
    _premiumChallenges.add(challenge);
  }

  // Update challenge (for admin use)
  static bool updateChallenge(String id, ChallengeModel updatedChallenge) {
    final index = _premiumChallenges.indexWhere((challenge) => challenge.id == id);
    if (index != -1) {
      _premiumChallenges[index] = updatedChallenge;
      return true;
    }
    return false;
  }

  // Remove challenge (for admin use)
  static bool removeChallenge(String id) {
    final challenge = getChallengeById(id);
    if (challenge != null) {
      _premiumChallenges.remove(challenge);
      return true;
    }
    return false;
  }
}
