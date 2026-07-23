const {
  withAndroidManifest,
  withAppBuildGradle,
  withDangerousMod,
  withGradleProperties,
  withMainActivity,
} = require('@expo/config-plugins');
const fs = require('node:fs');
const path = require('node:path');

const backupDomains = [
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
];

const deviceBackupDomains = [
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

function exclusionRules(domains, indentation) {
  return domains
    .map((domain) => `${indentation}<exclude domain="${domain}" path="."/>`)
    .join('\n');
}

function withPrivateLocalData(config) {
  config = withAndroidManifest(config, (config) => {
    const application = config.modResults.manifest.application?.[0];
    if (!application) {
      throw new Error('AndroidManifest.xml does not contain an application node.');
    }

    application.$['android:fullBackupContent'] = '@xml/backup_rules';
    application.$['android:dataExtractionRules'] = '@xml/data_extraction_rules';
    application.$['tools:targetApi'] = '33';

    const blockedStoragePermissions = new Set([
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]);
    for (const permission of config.modResults.manifest['uses-permission'] ?? []) {
      if (blockedStoragePermissions.has(permission.$?.['android:name'])) {
        permission.$['tools:ignore'] = 'ScopedStorage';
      }
    }

    return config;
  });

  return withDangerousMod(config, [
    'android',
    async (config) => {
      const mainRoot = path.join(
        config.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
      );
      const xmlRoot = path.join(mainRoot, 'res', 'xml');
      await fs.promises.mkdir(xmlRoot, { recursive: true });

      const legacyRules = `<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
${exclusionRules(backupDomains, '  ')}
</full-backup-content>
`;
      const allModernDomains = [...backupDomains, ...deviceBackupDomains];
      const modernRules = `<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
${exclusionRules(allModernDomains, '    ')}
  </cloud-backup>
  <device-transfer>
${exclusionRules(allModernDomains, '    ')}
  </device-transfer>
</data-extraction-rules>
`;

      await Promise.all([
        fs.promises.writeFile(path.join(xmlRoot, 'backup_rules.xml'), legacyRules),
        fs.promises.writeFile(
          path.join(xmlRoot, 'data_extraction_rules.xml'),
          modernRules,
        ),
      ]);

      const resRoot = path.join(mainRoot, 'res');
      for (const directory of await fs.promises.readdir(resRoot)) {
        if (!directory.startsWith('mipmap-')) continue;
        const directoryPath = path.join(resRoot, directory);
        for (const file of await fs.promises.readdir(directoryPath)) {
          if (!file.endsWith('.webp')) continue;
          const source = path.join(directoryPath, file);
          const header = Buffer.alloc(8);
          const handle = await fs.promises.open(source, 'r');
          await handle.read(header, 0, header.length, 0);
          await handle.close();
          if (header.equals(Buffer.from('89504e470d0a1a0a', 'hex'))) {
            await fs.promises.rename(source, source.replace(/\.webp$/, '.png'));
          }
        }
      }

      return config;
    },
  ]);
}

function withStableGradleMemory(config) {
  return withGradleProperties(config, (config) => {
    const key = 'org.gradle.jvmargs';
    const value = '-Xmx2048m -XX:MaxMetaspaceSize=1024m';
    const property = config.modResults.find(
      (item) => item.type === 'property' && item.key === key,
    );

    if (property) {
      property.value = value;
    } else {
      config.modResults.push({ type: 'property', key, value });
    }

    return config;
  });
}

function withHealthConnectDelegate(config) {
  return withMainActivity(config, (config) => {
    if (config.modResults.language !== 'kt') {
      throw new Error('TezDav Health Connect setup expects a Kotlin MainActivity.');
    }

    let source = config.modResults.contents;
    const delegateImport =
      'import dev.matinzd.healthconnect.permissions.HealthConnectPermissionDelegate';

    if (!source.includes(delegateImport)) {
      source = source.replace(
        'import android.os.Bundle',
        `import android.os.Bundle\n\n${delegateImport}`,
      );
    }

    const delegateSetup =
      'HealthConnectPermissionDelegate.setPermissionDelegate(this)';
    if (!source.includes(delegateSetup)) {
      source = source.replace(
        'super.onCreate(null)',
        `super.onCreate(null)\n    ${delegateSetup}`,
      );
    }

    config.modResults.contents = source;
    return config;
  });
}

function withHealthPermissionUsageAlias(config) {
  return withAndroidManifest(config, (config) => {
    const application = config.modResults.manifest.application?.[0];
    if (!application) {
      throw new Error('AndroidManifest.xml does not contain an application node.');
    }

    application['activity-alias'] ??= [];
    const aliases = application['activity-alias'];
    const aliasName = 'ViewPermissionUsageActivity';

    if (!aliases.some((alias) => alias.$?.['android:name'] === aliasName)) {
      aliases.push({
        $: {
          'android:name': aliasName,
          'android:exported': 'true',
          'android:targetActivity': '.MainActivity',
          'android:permission': 'android.permission.START_VIEW_PERMISSION_USAGE',
        },
        'intent-filter': [
          {
            action: [
              { $: { 'android:name': 'android.intent.action.VIEW_PERMISSION_USAGE' } },
            ],
            category: [
              { $: { 'android:name': 'android.intent.category.HEALTH_PERMISSIONS' } },
            ],
          },
        ],
      });
    }

    return config;
  });
}

function withReleaseSigningGuard(config) {
  return withAppBuildGradle(config, (config) => {
    if (config.modResults.language !== 'groovy') {
      throw new Error('TezDav release signing guard expects Groovy build.gradle.');
    }

    config.modResults.contents = config.modResults.contents.replace(
      /release \{\n\s*\/\/ Caution![\s\S]*?signingConfig signingConfigs\.debug/,
      `release {\n            // EAS supplies production signing. Local release builds stay unsigned\n            // unless an explicit upload keystore is configured.`,
    );
    return config;
  });
}

module.exports = function withAndroidHardening(config) {
  config = withStableGradleMemory(config);
  config = withPrivateLocalData(config);
  config = withHealthConnectDelegate(config);
  config = withHealthPermissionUsageAlias(config);
  config = withReleaseSigningGuard(config);
  return config;
};
