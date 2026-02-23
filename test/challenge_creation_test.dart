import 'package:flutter_test/flutter_test.dart';
import 'package:my_leadership_quest/models/challenge_model.dart';
import 'package:my_leadership_quest/services/admin_service.dart';

void main() {
  group('Challenge Creation Tests', () {
    test('ChallengeModel toJson should match database schema', () {
      final challenge = ChallengeModel(
        id: 'test-id',
        title: 'Test Challenge',
        description: 'Test Description',
        type: ChallengeType.premium,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        organizationId: 'org-1',
        organizationName: 'Test Org',
        organizationLogo: 'logo.png',
        criteria: ['Complete task 1', 'Complete task 2'],
        timeline: '30 days',
        isTeamChallenge: true,
        coinReward: 100,
        realWorldPrize: 'Gift Card',
      );

      final json = challenge.toJson();
      
      // Verify database field names
      expect(json['type'], 'premium');
      expect(json['real_world_prize'], 'Gift Card');
      expect(json['start_date'], isA<String>());
      expect(json['end_date'], isA<String>());
      expect(json['organization_id'], 'org-1');
      expect(json['organization_name'], 'Test Org');
      expect(json['organization_logo'], 'logo.png');
      expect(json['is_team_challenge'], true);
      expect(json['coin_reward'], 100);
      
      // Verify date format is ISO8601
      expect(DateTime.parse(json['start_date']), DateTime(2024, 1, 1));
      expect(DateTime.parse(json['end_date']), DateTime(2024, 1, 31));
    });

    test('ChallengeModel fromJson should parse database format', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Challenge',
        'description': 'Test Description',
        'type': 'basic',
        'real_world_prize': null,
        'start_date': '2024-01-01T00:00:00.000Z',
        'end_date': '2024-01-31T00:00:00.000Z',
        'participants_count': 5,
        'organization_id': 'org-1',
        'organization_name': 'Test Org',
        'organization_logo': 'logo.png',
        'criteria': ['Task 1', 'Task 2'],
        'timeline': '30 days',
        'is_team_challenge': false,
        'coin_reward': 50,
      };

      final challenge = ChallengeModel.fromJson(json);
      
      expect(challenge.type, ChallengeType.basic);
      expect(challenge.realWorldPrize, null);
      expect(challenge.startDate, DateTime.parse('2024-01-01T00:00:00.000Z'));
      expect(challenge.endDate, DateTime.parse('2024-01-31T00:00:00.000Z'));
      expect(challenge.participantsCount, 5);
      expect(challenge.isTeamChallenge, false);
      expect(challenge.coinReward, 50);
    });
  });
}
