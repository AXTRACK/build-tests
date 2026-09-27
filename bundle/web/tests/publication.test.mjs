import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  collectAllowedFiles,
  directoryCanContainAllowedFiles,
  extractLocalReferences,
  extractMarkdownAnchors,
  loadConfig,
  rewriteReaderAssetReferences,
  validateCompatibilityInboundLinks,
  validateMarkdownAnchors,
  validateQuickNavigation,
  validateReaderQuality,
  validateReaderReachability,
  validateTransitiveLinks
} from '../scripts/publication-lib.mjs';

const configPath = new URL('../config/publication.json', import.meta.url);
const config = await loadConfig(configPath);

async function withFixture(files, callback) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'kb-publication-'));
  try {
    for (const [relativePath, content] of Object.entries(files)) {
      const absolutePath = path.join(root, relativePath);
      await fs.mkdir(path.dirname(absolutePath), { recursive: true });
      await fs.writeFile(absolutePath, content, 'utf8');
    }
    await callback(root);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
}

test('allowlist includes reader surfaces and excludes maintainer surfaces', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Knowledge](knowledge/README.md)',
      'ABOUT.md': '# About',
      'THIRD_PARTY_NOTICES.md': '# Notices',
      'knowledge/README.md': '# Knowledge',
      'examples/README.md': '# Examples',
      'templates/README.md': '# Templates',
      'showcase/README.md': '# Showcase',
      'assets/icons/tabler/route.svg': '<svg/>',
      'catalog/sources.md': '# Internal',
      'sources/README.md': '# Internal',
      'AGENTS.md': '# Internal'
    },
    async (root) => {
      const files = await collectAllowedFiles(root, config);
      assert(files.includes('README.md'));
      assert(files.includes('knowledge/README.md'));
      assert(files.includes('assets/icons/tabler/route.svg'));
      assert(!files.includes('catalog/sources.md'));
      assert(!files.includes('sources/README.md'));
      assert(!files.includes('AGENTS.md'));
    }
  );
});

test('reader page linking to catalog fails the transitive boundary', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Do not publish](catalog/sources.md)',
      'ABOUT.md': '# About',
      'THIRD_PARTY_NOTICES.md': '# Notices',
      'catalog/sources.md': '# Internal'
    },
    async (root) => {
      const files = await collectAllowedFiles(root, config);
      const violations = await validateTransitiveLinks(root, files, config);
      assert.equal(violations.length, 1);
      assert.equal(violations[0].reason, 'TARGET_NOT_PUBLISHED');
      assert.equal(violations[0].target, 'catalog/sources.md');
    }
  );
});

test('missing relative reader targets fail closed', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Missing](knowledge/missing.md)',
      'ABOUT.md': '# About',
      'THIRD_PARTY_NOTICES.md': '# Notices'
    },
    async (root) => {
      const files = await collectAllowedFiles(root, config);
      const violations = await validateTransitiveLinks(root, files, config);
      assert.equal(violations.length, 1);
      assert.equal(violations[0].reason, 'MISSING');
      assert.equal(violations[0].target, 'knowledge/missing.md');
    }
  );
});

test('reader page linking outside repository fails closed', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Escape](../secret.md)',
      'ABOUT.md': '# About',
      'THIRD_PARTY_NOTICES.md': '# Notices'
    },
    async (root) => {
      const files = await collectAllowedFiles(root, config);
      const violations = await validateTransitiveLinks(root, files, config);
      assert.equal(violations.length, 1);
      assert.equal(violations[0].reason, 'ESCAPES_REPOSITORY');
    }
  );
});

test('allowed relative Markdown and local icon references pass', async () => {
  await withFixture(
    {
      'README.md':
        '# Home\n[Knowledge](knowledge/README.md)\n<img src="assets/icons/tabler/route.svg" alt="">',
      'ABOUT.md': '# About',
      'THIRD_PARTY_NOTICES.md': '# Notices',
      'knowledge/README.md': '# Knowledge',
      'assets/icons/tabler/route.svg': '<svg/>'
    },
    async (root) => {
      const files = await collectAllowedFiles(root, config);
      const violations = await validateTransitiveLinks(root, files, config);
      assert.deepEqual(violations, []);
    }
  );
});

test('external URLs and anchors are not treated as repository paths', () => {
  const refs = extractLocalReferences(
    '[External](https://example.com) [Anchor](#section) [Local](knowledge/README.md)'
  );
  assert.deepEqual(refs, ['knowledge/README.md']);
});

test('publication walk prunes non-reader roots before descending', () => {
  assert.equal(directoryCanContainAllowedFiles('.git', config), false);
  assert.equal(directoryCanContainAllowedFiles('web', config), false);
  assert.equal(directoryCanContainAllowedFiles('catalog', config), false);
  assert.equal(directoryCanContainAllowedFiles('assets', config), true);
  assert.equal(directoryCanContainAllowedFiles('assets/icons', config), true);
  assert.equal(directoryCanContainAllowedFiles('assets/icons/tabler', config), true);
});

test('reader asset references are normalized only in generated Markdown', () => {
  const root = rewriteReaderAssetReferences(
    '<img src="assets/icons/tabler/route.svg" alt="">',
    'README.md'
  );
  assert.equal(root, '<img src="/assets/icons/tabler/route.svg" alt="">');

  const nested = rewriteReaderAssetReferences(
    '<img src="../assets/icons/tabler/route.svg" alt="">',
    'showcase/README.md'
  );
  assert.equal(nested, '<img src="/assets/icons/tabler/route.svg" alt="">');

  const ordinaryLink = rewriteReaderAssetReferences(
    '[Decision](knowledge/decision-router.md)',
    'README.md'
  );
  assert.equal(ordinaryLink, '[Decision](knowledge/decision-router.md)');
});


test('Markdown anchor validation detects stale anchors and accepts explicit anchors', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Valid](knowledge/page.md#current-heading)\n[Explicit](knowledge/page.md#stable-anchor)\n[Stale](knowledge/page.md#old-heading)',
      'knowledge/page.md': '# Page\n\n<a id="stable-anchor"></a>\n## Current heading'
    },
    async (root) => {
      const files = ['README.md', 'knowledge/page.md'];
      const violations = await validateMarkdownAnchors(root, files);
      assert.deepEqual(
        violations.map((item) => item.reason),
        ['MISSING_ANCHOR']
      );
      assert.equal(violations[0].reference, 'knowledge/page.md#old-heading');

      const anchors = extractMarkdownAnchors(
        '# Page\n## Repeated heading\n## Repeated heading'
      );
      assert(anchors.has('page'));
      assert(anchors.has('repeated-heading'));
      assert(anchors.has('repeated-heading-1'));
    }
  );
});

test('reader reachability reports orphan canonical pages and ignores compatibility stubs', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Reachable](knowledge/reachable.md)',
      'knowledge/reachable.md': '# Reachable',
      'knowledge/orphan.md': '# Orphan',
      'knowledge/compat.md': '# Compatibility'
    },
    async (root) => {
      const files = [
        'README.md',
        'knowledge/reachable.md',
        'knowledge/orphan.md',
        'knowledge/compat.md'
      ];
      const localConfig = {
        readerEntryPoints: ['README.md'],
        reachabilityRequiredRoots: ['knowledge'],
        compatibilityPages: ['knowledge/compat.md']
      };
      const violations = await validateReaderReachability(
        root,
        files,
        localConfig
      );
      assert.deepEqual(
        violations.map((item) => item.target),
        ['knowledge/orphan.md']
      );
    }
  );
});

test('reader links must bypass compatibility pages', async () => {
  await withFixture(
    {
      'README.md': '# Home\n[Old route](knowledge/compat.md)',
      'knowledge/compat.md': '# Compatibility\n[Current](current.md)',
      'knowledge/current.md': '# Current'
    },
    async (root) => {
      const files = [
        'README.md',
        'knowledge/compat.md',
        'knowledge/current.md'
      ];
      const violations = await validateCompatibilityInboundLinks(
        root,
        files,
        { compatibilityPages: ['knowledge/compat.md'] }
      );
      assert.equal(violations.length, 1);
      assert.equal(violations[0].reason, 'COMPATIBILITY_PAGE_LINKED');
      assert.equal(violations[0].source, 'README.md');
    }
  );
});

test('quick navigation enforces order and omits a current-page self-link', async () => {
  await withFixture(
    {
      'hub.md':
        '# Hub\n**Quick navigation:** [Second](second.md)',
      'second.md':
        '# Second\n**Quick navigation:** [Hub](hub.md)'
    },
    async (root) => {
      const localConfig = {
        quickNavigation: {
          items: [
            { label: 'Hub', path: 'hub.md' },
            { label: 'Second', path: 'second.md' }
          ],
          surfaces: ['hub.md', 'second.md']
        }
      };
      assert.deepEqual(
        await validateQuickNavigation(root, localConfig),
        []
      );

      await fs.writeFile(
        path.join(root, 'second.md'),
        '# Second\n**Quick navigation:** [Second](second.md) · [Hub](hub.md)',
        'utf8'
      );
      const violations = await validateQuickNavigation(root, localConfig);
      assert(violations.some((item) => item.reason === 'QUICK_NAV_SELF_LINK'));
      assert(violations.some((item) => item.reason === 'QUICK_NAV_MISMATCH'));
    }
  );
});

test('reader quality aggregates link, anchor, reachability, compatibility, and navigation checks', async () => {
  await withFixture(
    {
      'README.md':
        '# Home\n**Quick navigation:** [Guide](knowledge/guide.md)\n[Guide](knowledge/guide.md)',
      'knowledge/guide.md':
        '# Guide\n**Quick navigation:** [Home](../README.md)\n[Broken](#missing)',
      'knowledge/orphan.md': '# Orphan'
    },
    async (root) => {
      const files = [
        'README.md',
        'knowledge/guide.md',
        'knowledge/orphan.md'
      ];
      const localConfig = {
        forbiddenRoots: [],
        rootFiles: ['README.md'],
        roots: [{ path: 'knowledge', extensions: ['.md'] }],
        readerEntryPoints: ['README.md'],
        reachabilityRequiredRoots: ['knowledge'],
        compatibilityPages: [],
        quickNavigation: {
          items: [
            { label: 'Home', path: 'README.md' },
            { label: 'Guide', path: 'knowledge/guide.md' }
          ],
          surfaces: ['README.md', 'knowledge/guide.md']
        }
      };
      const violations = await validateReaderQuality(
        root,
        files,
        localConfig
      );
      assert(violations.some((item) => item.reason === 'MISSING_ANCHOR'));
      assert(violations.some((item) => item.reason === 'UNREACHABLE_READER_PAGE'));
    }
  );
});
