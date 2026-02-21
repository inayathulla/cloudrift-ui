import 'package:flutter_test/flutter_test.dart';
import 'package:cloudrift_ui/data/models/plan_builder.dart';

void main() {
  group('IAMRoleDef', () {
    test('toChangeAfter includes required fields', () {
      final role = IAMRoleDef(
        roleName: 'test-role',
        path: '/service/',
        assumeRolePolicy: '{"Version":"2012-10-17"}',
        maxSessionDuration: 7200,
        description: 'Test role',
        tags: {'env': 'prod'},
        attachedPolicies: ['arn:aws:iam::policy/ReadOnly'],
      );

      final after = role.toChangeAfter();
      expect(after['name'], 'test-role');
      expect(after['path'], '/service/');
      expect(after['assume_role_policy'], '{"Version":"2012-10-17"}');
      expect(after['max_session_duration'], 7200);
      expect(after['description'], 'Test role');
      expect(after['tags'], {'env': 'prod'});
      expect(after['attached_policies'], ['arn:aws:iam::policy/ReadOnly']);
    });

    test('toChangeAfter omits empty optional fields', () {
      final role = IAMRoleDef(roleName: 'minimal-role');

      final after = role.toChangeAfter();
      expect(after['name'], 'minimal-role');
      expect(after.containsKey('assume_role_policy'), false);
      expect(after.containsKey('description'), false);
      expect(after.containsKey('tags'), false);
      expect(after.containsKey('attached_policies'), false);
    });

    test('fromChangeAfter round-trips correctly', () {
      final original = IAMRoleDef(
        roleName: 'round-trip',
        path: '/apps/',
        assumeRolePolicy: '{"Statement":[]}',
        maxSessionDuration: 3600,
        description: 'A role',
        tags: {'team': 'infra'},
        attachedPolicies: ['arn:aws:iam::policy/Admin'],
      );

      final parsed = IAMRoleDef.fromChangeAfter(original.toChangeAfter());
      expect(parsed.roleName, original.roleName);
      expect(parsed.path, original.path);
      expect(parsed.assumeRolePolicy, original.assumeRolePolicy);
      expect(parsed.maxSessionDuration, original.maxSessionDuration);
      expect(parsed.description, original.description);
      expect(parsed.tags, original.tags);
      expect(parsed.attachedPolicies, original.attachedPolicies);
    });
  });

  group('IAMUserDef', () {
    test('toChangeAfter includes required fields', () {
      final user = IAMUserDef(
        userName: 'deploy-bot',
        path: '/bots/',
        tags: {'purpose': 'ci'},
        attachedPolicies: ['arn:aws:iam::policy/Deploy'],
      );

      final after = user.toChangeAfter();
      expect(after['name'], 'deploy-bot');
      expect(after['path'], '/bots/');
      expect(after['tags'], {'purpose': 'ci'});
      expect(after['attached_policies'], ['arn:aws:iam::policy/Deploy']);
    });

    test('fromChangeAfter round-trips correctly', () {
      final original = IAMUserDef(
        userName: 'admin-user',
        path: '/',
        tags: {'dept': 'eng'},
        attachedPolicies: ['arn:aws:iam::policy/Admin'],
      );

      final parsed = IAMUserDef.fromChangeAfter(original.toChangeAfter());
      expect(parsed.userName, original.userName);
      expect(parsed.path, original.path);
      expect(parsed.tags, original.tags);
      expect(parsed.attachedPolicies, original.attachedPolicies);
    });
  });

  group('IAMPolicyDef', () {
    test('toChangeAfter includes required fields', () {
      final policy = IAMPolicyDef(
        policyName: 'S3ReadOnly',
        path: '/custom/',
        policyDocument: '{"Version":"2012-10-17","Statement":[]}',
        description: 'S3 read-only',
        tags: {'scope': 's3'},
      );

      final after = policy.toChangeAfter();
      expect(after['name'], 'S3ReadOnly');
      expect(after['path'], '/custom/');
      expect(after['policy'], '{"Version":"2012-10-17","Statement":[]}');
      expect(after['description'], 'S3 read-only');
      expect(after['tags'], {'scope': 's3'});
    });

    test('fromChangeAfter round-trips correctly', () {
      final original = IAMPolicyDef(
        policyName: 'TestPolicy',
        policyDocument: '{}',
        description: 'test',
      );

      final parsed = IAMPolicyDef.fromChangeAfter(original.toChangeAfter());
      expect(parsed.policyName, original.policyName);
      expect(parsed.policyDocument, original.policyDocument);
      expect(parsed.description, original.description);
    });
  });

  group('IAMGroupDef', () {
    test('toChangeAfter includes required fields', () {
      final group = IAMGroupDef(
        groupName: 'developers',
        path: '/teams/',
        attachedPolicies: ['arn:aws:iam::policy/Dev'],
        members: ['alice', 'bob'],
      );

      final after = group.toChangeAfter();
      expect(after['name'], 'developers');
      expect(after['path'], '/teams/');
      expect(after['attached_policies'], ['arn:aws:iam::policy/Dev']);
      expect(after['members'], ['alice', 'bob']);
    });

    test('fromChangeAfter round-trips correctly', () {
      final original = IAMGroupDef(
        groupName: 'admins',
        members: ['root'],
        attachedPolicies: ['arn:aws:iam::policy/Admin'],
      );

      final parsed = IAMGroupDef.fromChangeAfter(original.toChangeAfter());
      expect(parsed.groupName, original.groupName);
      expect(parsed.members, original.members);
      expect(parsed.attachedPolicies, original.attachedPolicies);
    });
  });

  group('PlanBuilder.generateIAMPlan', () {
    test('generates plan with all 4 resource types', () {
      final plan = PlanBuilder.generateIAMPlan(
        roles: [IAMRoleDef(roleName: 'web-role')],
        users: [IAMUserDef(userName: 'deploy-user')],
        policies: [IAMPolicyDef(policyName: 'read-policy')],
        groups: [IAMGroupDef(groupName: 'devs')],
      );

      final changes = plan['resource_changes'] as List;
      expect(changes.length, 4);

      // Verify resource types in order: roles, users, policies, groups.
      expect(changes[0]['type'], 'aws_iam_role');
      expect(changes[0]['address'], 'aws_iam_role.web_role');
      expect(changes[1]['type'], 'aws_iam_user');
      expect(changes[1]['address'], 'aws_iam_user.deploy_user');
      expect(changes[2]['type'], 'aws_iam_policy');
      expect(changes[2]['address'], 'aws_iam_policy.read_policy');
      expect(changes[3]['type'], 'aws_iam_group');
      expect(changes[3]['address'], 'aws_iam_group.devs');

      // Verify each change has 'create' action.
      for (final change in changes) {
        expect(
          (change['change'] as Map)['actions'],
          ['create'],
        );
      }
    });

    test('generates empty plan when no resources given', () {
      final plan = PlanBuilder.generateIAMPlan();
      expect((plan['resource_changes'] as List).isEmpty, true);
    });

    test('sanitizes special characters in resource addresses', () {
      final plan = PlanBuilder.generateIAMPlan(
        roles: [IAMRoleDef(roleName: 'my-special.role@v2')],
      );

      final changes = plan['resource_changes'] as List;
      expect(changes[0]['address'], 'aws_iam_role.my_special_role_v2');
    });
  });

  group('PlanBuilder.parseIAM*', () {
    test('parseIAMRoles round-trips through generateIAMPlan', () {
      final original = [
        IAMRoleDef(roleName: 'role-a', description: 'First'),
        IAMRoleDef(roleName: 'role-b', path: '/custom/'),
      ];

      final plan = PlanBuilder.generateIAMPlan(roles: original);
      final parsed = PlanBuilder.parseIAMRoles(plan);

      expect(parsed.length, 2);
      expect(parsed[0].roleName, 'role-a');
      expect(parsed[0].description, 'First');
      expect(parsed[1].roleName, 'role-b');
      expect(parsed[1].path, '/custom/');
    });

    test('parseIAMUsers round-trips through generateIAMPlan', () {
      final original = [IAMUserDef(userName: 'alice')];

      final plan = PlanBuilder.generateIAMPlan(users: original);
      final parsed = PlanBuilder.parseIAMUsers(plan);

      expect(parsed.length, 1);
      expect(parsed[0].userName, 'alice');
    });

    test('parseIAMPolicies round-trips through generateIAMPlan', () {
      final original = [
        IAMPolicyDef(policyName: 'custom-pol', policyDocument: '{}'),
      ];

      final plan = PlanBuilder.generateIAMPlan(policies: original);
      final parsed = PlanBuilder.parseIAMPolicies(plan);

      expect(parsed.length, 1);
      expect(parsed[0].policyName, 'custom-pol');
      expect(parsed[0].policyDocument, '{}');
    });

    test('parseIAMGroups round-trips through generateIAMPlan', () {
      final original = [
        IAMGroupDef(groupName: 'ops', members: ['bob', 'carol']),
      ];

      final plan = PlanBuilder.generateIAMPlan(groups: original);
      final parsed = PlanBuilder.parseIAMGroups(plan);

      expect(parsed.length, 1);
      expect(parsed[0].groupName, 'ops');
      expect(parsed[0].members, ['bob', 'carol']);
    });

    test('parsers ignore other resource types in mixed plan', () {
      // A plan with all types mixed together.
      final plan = PlanBuilder.generateIAMPlan(
        roles: [IAMRoleDef(roleName: 'r1')],
        users: [IAMUserDef(userName: 'u1')],
        policies: [IAMPolicyDef(policyName: 'p1')],
        groups: [IAMGroupDef(groupName: 'g1')],
      );

      // Each parser should only find its own type.
      expect(PlanBuilder.parseIAMRoles(plan).length, 1);
      expect(PlanBuilder.parseIAMUsers(plan).length, 1);
      expect(PlanBuilder.parseIAMPolicies(plan).length, 1);
      expect(PlanBuilder.parseIAMGroups(plan).length, 1);
    });

    test('parsers return empty list for plan with no matching types', () {
      final s3Plan = PlanBuilder.generateS3Plan([
        S3ResourceDef(bucket: 'my-bucket'),
      ]);

      expect(PlanBuilder.parseIAMRoles(s3Plan), isEmpty);
      expect(PlanBuilder.parseIAMUsers(s3Plan), isEmpty);
      expect(PlanBuilder.parseIAMPolicies(s3Plan), isEmpty);
      expect(PlanBuilder.parseIAMGroups(s3Plan), isEmpty);
    });
  });
}
