// ---------------------------------------------------------------------------
// S3 Resource Definition
// ---------------------------------------------------------------------------

class S3ResourceDef {
  String bucket;
  String acl;
  bool versioningEnabled;
  String sseAlgorithm;
  String loggingTargetBucket;
  String loggingTargetPrefix;
  bool blockPublicAcls;
  bool ignorePublicAcls;
  bool blockPublicPolicy;
  bool restrictPublicBuckets;
  Map<String, String> tags;
  List<LifecycleRuleDef> lifecycleRules;

  S3ResourceDef({
    this.bucket = '',
    this.acl = 'private',
    this.versioningEnabled = false,
    this.sseAlgorithm = 'AES256',
    this.loggingTargetBucket = '',
    this.loggingTargetPrefix = '',
    this.blockPublicAcls = true,
    this.ignorePublicAcls = true,
    this.blockPublicPolicy = true,
    this.restrictPublicBuckets = true,
    Map<String, String>? tags,
    List<LifecycleRuleDef>? lifecycleRules,
  })  : tags = tags ?? {},
        lifecycleRules = lifecycleRules ?? [];

  Map<String, dynamic> toChangeAfter() {
    final after = <String, dynamic>{
      'bucket': bucket,
      'acl': acl,
      'versioning': {'enabled': versioningEnabled},
      'server_side_encryption_configuration': {
        'rules': [
          {
            'apply_server_side_encryption_by_default': {
              'sse_algorithm': sseAlgorithm,
            },
          },
        ],
      },
      'public_access_block': {
        'block_public_acls': blockPublicAcls,
        'ignore_public_acls': ignorePublicAcls,
        'block_public_policy': blockPublicPolicy,
        'restrict_public_buckets': restrictPublicBuckets,
      },
    };

    if (tags.isNotEmpty) {
      after['tags'] = tags;
    }
    if (loggingTargetBucket.isNotEmpty) {
      after['logging'] = {
        'target_bucket': loggingTargetBucket,
        'target_prefix': loggingTargetPrefix,
      };
    }
    if (lifecycleRules.isNotEmpty) {
      after['lifecycle_rule'] = lifecycleRules.map((r) => r.toJson()).toList();
    }

    return after;
  }

  /// Parses from an existing plan.json `change.after` map.
  factory S3ResourceDef.fromChangeAfter(Map<String, dynamic> after) {
    final versioning = after['versioning'] as Map<String, dynamic>?;
    final encryption = after['server_side_encryption_configuration']
        as Map<String, dynamic>?;
    final logging = after['logging'] as Map<String, dynamic>?;
    final publicAccess = after['public_access_block'] as Map<String, dynamic>?;
    final tagsRaw = after['tags'] as Map<String, dynamic>?;
    final rulesRaw = after['lifecycle_rule'] as List<dynamic>?;

    String sseAlgo = 'AES256';
    if (encryption != null) {
      final rules = encryption['rules'] as List<dynamic>?;
      if (rules != null && rules.isNotEmpty) {
        final rule = rules[0] as Map<String, dynamic>;
        final defaults = rule['apply_server_side_encryption_by_default']
            as Map<String, dynamic>?;
        sseAlgo = defaults?['sse_algorithm'] as String? ?? 'AES256';
      }
    }

    return S3ResourceDef(
      bucket: after['bucket'] as String? ?? '',
      acl: after['acl'] as String? ?? 'private',
      versioningEnabled: versioning?['enabled'] as bool? ?? false,
      sseAlgorithm: sseAlgo,
      loggingTargetBucket: logging?['target_bucket'] as String? ?? '',
      loggingTargetPrefix: logging?['target_prefix'] as String? ?? '',
      blockPublicAcls: publicAccess?['block_public_acls'] as bool? ?? true,
      ignorePublicAcls: publicAccess?['ignore_public_acls'] as bool? ?? true,
      blockPublicPolicy: publicAccess?['block_public_policy'] as bool? ?? true,
      restrictPublicBuckets:
          publicAccess?['restrict_public_buckets'] as bool? ?? true,
      tags: tagsRaw?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      lifecycleRules:
          rulesRaw?.map((r) => LifecycleRuleDef.fromJson(r as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class LifecycleRuleDef {
  String id;
  String status;
  String prefix;
  int expirationDays;

  LifecycleRuleDef({
    this.id = '',
    this.status = 'Enabled',
    this.prefix = '',
    this.expirationDays = 90,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'prefix': prefix,
        'expiration': {'days': expirationDays},
      };

  factory LifecycleRuleDef.fromJson(Map<String, dynamic> json) {
    final expiration = json['expiration'] as Map<String, dynamic>?;
    return LifecycleRuleDef(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'Enabled',
      prefix: json['prefix'] as String? ?? '',
      expirationDays: (expiration?['days'] as num?)?.toInt() ?? 90,
    );
  }
}

// ---------------------------------------------------------------------------
// EC2 Resource Definition
// ---------------------------------------------------------------------------

class EC2ResourceDef {
  String address;
  String instanceType;
  String ami;
  String subnetId;
  String availabilityZone;
  String keyName;
  String iamInstanceProfile;
  bool ebsOptimized;
  bool monitoring;
  List<String> securityGroupIds;
  Map<String, String> tags;
  String rootVolumeType;
  int rootVolumeSize;
  bool rootVolumeEncrypted;

  EC2ResourceDef({
    this.address = 'aws_instance.server',
    this.instanceType = 't3.micro',
    this.ami = '',
    this.subnetId = '',
    this.availabilityZone = '',
    this.keyName = '',
    this.iamInstanceProfile = '',
    this.ebsOptimized = false,
    this.monitoring = false,
    List<String>? securityGroupIds,
    Map<String, String>? tags,
    this.rootVolumeType = 'gp3',
    this.rootVolumeSize = 20,
    this.rootVolumeEncrypted = true,
  })  : securityGroupIds = securityGroupIds ?? [],
        tags = tags ?? {};

  Map<String, dynamic> toChangeAfter() {
    final after = <String, dynamic>{
      'instance_type': instanceType,
      'ami': ami,
      'ebs_optimized': ebsOptimized,
      'monitoring': monitoring,
      'root_block_device': [
        {
          'volume_type': rootVolumeType,
          'volume_size': rootVolumeSize,
          'encrypted': rootVolumeEncrypted,
          'delete_on_termination': true,
        },
      ],
    };

    if (subnetId.isNotEmpty) after['subnet_id'] = subnetId;
    if (availabilityZone.isNotEmpty) {
      after['availability_zone'] = availabilityZone;
    }
    if (keyName.isNotEmpty) after['key_name'] = keyName;
    if (iamInstanceProfile.isNotEmpty) {
      after['iam_instance_profile'] = iamInstanceProfile;
    }
    if (securityGroupIds.isNotEmpty) {
      after['vpc_security_group_ids'] = securityGroupIds;
    }
    if (tags.isNotEmpty) after['tags'] = tags;

    return after;
  }

  factory EC2ResourceDef.fromChangeAfter(
      String address, Map<String, dynamic> after) {
    final tagsRaw = after['tags'] as Map<String, dynamic>?;
    final sgIds = after['vpc_security_group_ids'] as List<dynamic>?;
    final rootDev = after['root_block_device'] as List<dynamic>?;
    final rootMap =
        rootDev != null && rootDev.isNotEmpty ? rootDev[0] as Map<String, dynamic> : null;

    return EC2ResourceDef(
      address: address,
      instanceType: after['instance_type'] as String? ?? 't3.micro',
      ami: after['ami'] as String? ?? '',
      subnetId: after['subnet_id'] as String? ?? '',
      availabilityZone: after['availability_zone'] as String? ?? '',
      keyName: after['key_name'] as String? ?? '',
      iamInstanceProfile: after['iam_instance_profile'] as String? ?? '',
      ebsOptimized: after['ebs_optimized'] as bool? ?? false,
      monitoring: after['monitoring'] as bool? ?? false,
      securityGroupIds: sgIds?.map((e) => e.toString()).toList() ?? [],
      tags: tagsRaw?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      rootVolumeType: rootMap?['volume_type'] as String? ?? 'gp3',
      rootVolumeSize: (rootMap?['volume_size'] as num?)?.toInt() ?? 20,
      rootVolumeEncrypted: rootMap?['encrypted'] as bool? ?? true,
    );
  }
}

// ---------------------------------------------------------------------------
// Plan JSON Generator
// ---------------------------------------------------------------------------

class PlanBuilder {
  /// Generates a plan.json map for S3 resources.
  static Map<String, dynamic> generateS3Plan(List<S3ResourceDef> resources) {
    return {
      'resource_changes': resources.map((r) {
        final name = r.bucket.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        return {
          'address': 'aws_s3_bucket.$name',
          'type': 'aws_s3_bucket',
          'name': name,
          'change': {
            'actions': ['create'],
            'after': r.toChangeAfter(),
          },
        };
      }).toList(),
    };
  }

  /// Generates a plan.json map for EC2 resources.
  static Map<String, dynamic> generateEC2Plan(List<EC2ResourceDef> resources) {
    return {
      'resource_changes': resources.map((r) {
        final parts = r.address.split('.');
        final name = parts.length > 1 ? parts[1] : parts[0];
        return {
          'address': r.address,
          'type': 'aws_instance',
          'name': name,
          'change': {
            'actions': ['create'],
            'after': r.toChangeAfter(),
          },
        };
      }).toList(),
    };
  }

  /// Parses an existing plan.json map back into S3 resource definitions.
  static List<S3ResourceDef> parseS3Plan(Map<String, dynamic> plan) {
    final changes = plan['resource_changes'] as List<dynamic>? ?? [];
    return changes
        .where((rc) => (rc as Map<String, dynamic>)['type'] == 'aws_s3_bucket')
        .map((rc) {
      final change = (rc as Map<String, dynamic>)['change'] as Map<String, dynamic>;
      final after = change['after'] as Map<String, dynamic>? ?? {};
      return S3ResourceDef.fromChangeAfter(after);
    }).toList();
  }

  /// Parses an existing plan.json map back into EC2 resource definitions.
  static List<EC2ResourceDef> parseEC2Plan(Map<String, dynamic> plan) {
    final changes = plan['resource_changes'] as List<dynamic>? ?? [];
    return changes
        .where((rc) => (rc as Map<String, dynamic>)['type'] == 'aws_instance')
        .map((rc) {
      final rcMap = rc as Map<String, dynamic>;
      final change = rcMap['change'] as Map<String, dynamic>;
      final after = change['after'] as Map<String, dynamic>? ?? {};
      return EC2ResourceDef.fromChangeAfter(
          rcMap['address'] as String? ?? 'aws_instance.server', after);
    }).toList();
  }
}
