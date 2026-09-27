import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const MARKDOWN_LINK_RE = /!?\[[^\]]*\]\(([^)]+)\)/g;
const HTML_LINK_RE = /\b(?:href|src)\s*=\s*["']([^"']+)["']/gi;

export async function loadConfig(configPath) {
  const raw = await fs.readFile(configPath, 'utf8');
  const config = JSON.parse(raw);
  if (config.schemaVersion !== 1) {
    throw new Error(`Unsupported publication config schema: ${config.schemaVersion}`);
  }
  return config;
}

export function normalizeRepoPath(value) {
  const normalized = path.posix.normalize(value.replaceAll('\\', '/'));
  return normalized.replace(/^\.\//, '');
}

export function isForbidden(repoPath, config) {
  const normalized = normalizeRepoPath(repoPath);
  return config.forbiddenRoots.some((root) =>
    normalized === root || normalized.startsWith(`${root}/`)
  );
}

function extensionAllowed(repoPath, extensions) {
  return extensions.includes(path.posix.extname(repoPath).toLowerCase());
}

export function isAllowed(repoPath, config) {
  const normalized = normalizeRepoPath(repoPath);

  if (
    normalized === '..' ||
    normalized.startsWith('../') ||
    path.posix.isAbsolute(normalized) ||
    isForbidden(normalized, config)
  ) {
    return false;
  }

  if (config.rootFiles.includes(normalized)) {
    return true;
  }

  return config.roots.some(({ path: root, extensions }) => {
    if (!(normalized === root || normalized.startsWith(`${root}/`))) {
      return false;
    }
    return extensionAllowed(normalized, extensions);
  });
}

export function directoryCanContainAllowedFiles(relativeDir, config) {
  if (!relativeDir) {
    return true;
  }

  const normalized = normalizeRepoPath(relativeDir);
  if (isForbidden(normalized, config)) {
    return false;
  }

  return config.roots.some(({ path: root }) =>
    root === normalized ||
    root.startsWith(`${normalized}/`) ||
    normalized.startsWith(`${root}/`)
  );
}

async function walkFiles(rootDir, config, relativeDir = '') {
  const absoluteDir = path.join(rootDir, relativeDir);
  const entries = await fs.readdir(absoluteDir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const relativePath = normalizeRepoPath(path.posix.join(relativeDir, entry.name));
    if (entry.isDirectory()) {
      if (directoryCanContainAllowedFiles(relativePath, config)) {
        files.push(...await walkFiles(rootDir, config, relativePath));
      }
    } else if (entry.isFile() && isAllowed(relativePath, config)) {
      files.push(relativePath);
    }
  }

  return files;
}

export async function collectAllowedFiles(repoRoot, config) {
  return (await walkFiles(repoRoot, config)).sort();
}

function resolveLexicalReference(sourcePath, reference) {
  const sourceDir = path.posix.dirname(sourcePath);
  return normalizeRepoPath(path.posix.join(sourceDir, reference));
}

export function rewriteReaderAssetReferences(markdown, sourcePath) {
  const rewrite = (rawReference) => {
    const [pathAndQuery, hash = ''] = rawReference.split('#', 2);
    const [rawPath, query = ''] = pathAndQuery.split('?', 2);

    if (
      !rawPath ||
      rawPath.startsWith('/') ||
      rawPath.startsWith('//') ||
      /^[a-z][a-z0-9+.-]*:/i.test(rawPath)
    ) {
      return rawReference;
    }

    let decoded = rawPath;
    try {
      decoded = decodeURIComponent(rawPath);
    } catch {
      // Keep the original path when it is not valid percent-encoding.
    }

    const target = resolveLexicalReference(sourcePath, decoded);
    if (!target.startsWith('assets/')) {
      return rawReference;
    }

    const suffix =
      (query ? `?${query}` : '') +
      (hash ? `#${hash}` : '');

    return `/${target}${suffix}`;
  };

  let rewritten = markdown.replace(
    /(!?\[[^\]]*\]\()([^)\s]+)(\))/g,
    (match, prefix, reference, suffix) =>
      `${prefix}${rewrite(reference)}${suffix}`
  );

  rewritten = rewritten.replace(
    /(\b(?:href|src)\s*=\s*["'])([^"']+)(["'])/gi,
    (match, prefix, reference, suffix) =>
      `${prefix}${rewrite(reference)}${suffix}`
  );

  return rewritten;
}

export async function copyPublication(
  repoRoot,
  contentRoot,
  publicRoot,
  allowedFiles
) {
  await fs.rm(contentRoot, { recursive: true, force: true });
  await fs.rm(publicRoot, { recursive: true, force: true });
  await fs.mkdir(contentRoot, { recursive: true });
  await fs.mkdir(publicRoot, { recursive: true });

  for (const repoPath of allowedFiles) {
    const source = path.join(repoRoot, repoPath);

    if (repoPath.startsWith('assets/')) {
      const destination = path.join(publicRoot, repoPath);
      await fs.mkdir(path.dirname(destination), { recursive: true });
      await fs.copyFile(source, destination);
      continue;
    }

    const destination = path.join(contentRoot, repoPath);
    await fs.mkdir(path.dirname(destination), { recursive: true });

    if (repoPath.endsWith('.md')) {
      const markdown = await fs.readFile(source, 'utf8');
      await fs.writeFile(
        destination,
        rewriteReaderAssetReferences(markdown, repoPath),
        'utf8'
      );
    } else {
      await fs.copyFile(source, destination);
    }
  }
}

function cleanReference(rawReference) {
  let value = rawReference.trim();

  if (value.startsWith('<') && value.endsWith('>')) {
    value = value.slice(1, -1);
  }

  const titleMatch = value.match(/^(\S+)(?:\s+["'][^"']*["'])?$/);
  if (titleMatch) {
    value = titleMatch[1];
  }

  return value;
}

export function extractLocalReferences(markdown) {
  const refs = new Set();

  for (const regex of [MARKDOWN_LINK_RE, HTML_LINK_RE]) {
    regex.lastIndex = 0;
    for (const match of markdown.matchAll(regex)) {
      const raw = cleanReference(match[1]);
      if (!raw || raw.startsWith('#')) {
        continue;
      }

      if (
        raw.startsWith('/') ||
        /^[a-z][a-z0-9+.-]*:/i.test(raw) ||
        raw.startsWith('//')
      ) {
        continue;
      }

      const withoutHash = raw.split('#', 1)[0].split('?', 1)[0];
      if (!withoutHash) {
        continue;
      }

      try {
        refs.add(decodeURIComponent(withoutHash));
      } catch {
        refs.add(withoutHash);
      }
    }
  }

  return [...refs];
}

async function exists(filePath) {
  try {
    const stat = await fs.stat(filePath);
    return stat.isFile();
  } catch {
    return false;
  }
}

export async function resolveReference(sourcePath, reference, repoRoot) {
  const sourceDir = path.posix.dirname(sourcePath);
  const candidate = normalizeRepoPath(path.posix.join(sourceDir, reference));

  if (
    candidate === '..' ||
    candidate.startsWith('../') ||
    path.posix.isAbsolute(candidate)
  ) {
    return { status: 'ESCAPES_REPOSITORY', target: candidate };
  }

  const candidates = [candidate];
  if (!path.posix.extname(candidate)) {
    candidates.push(`${candidate}.md`);
    candidates.push(path.posix.join(candidate, 'README.md'));
  }

  for (const target of candidates) {
    if (await exists(path.join(repoRoot, target))) {
      return { status: 'FOUND', target };
    }
  }

  return { status: 'MISSING', target: candidate };
}

export async function validateTransitiveLinks(repoRoot, allowedFiles, config) {
  const allowed = new Set(allowedFiles);
  const violations = [];

  for (const sourcePath of allowedFiles.filter((file) => file.endsWith('.md'))) {
    const markdown = await fs.readFile(path.join(repoRoot, sourcePath), 'utf8');
    const references = extractLocalReferences(markdown);

    for (const reference of references) {
      const resolution = await resolveReference(sourcePath, reference, repoRoot);

      if (resolution.status !== 'FOUND') {
        violations.push({
          source: sourcePath,
          reference,
          target: resolution.target,
          reason: resolution.status
        });
        continue;
      }

      if (!allowed.has(resolution.target) || !isAllowed(resolution.target, config)) {
        violations.push({
          source: sourcePath,
          reference,
          target: resolution.target,
          reason: 'TARGET_NOT_PUBLISHED'
        });
      }
    }
  }

  return violations;
}


function decodeReferenceValue(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function extractLocalLinkTargets(markdown) {
  const refs = [];

  for (const regex of [MARKDOWN_LINK_RE, HTML_LINK_RE]) {
    regex.lastIndex = 0;
    for (const match of markdown.matchAll(regex)) {
      const raw = cleanReference(match[1]);
      if (
        !raw ||
        raw.startsWith('/') ||
        raw.startsWith('//') ||
        /^[a-z][a-z0-9+.-]*:/i.test(raw)
      ) {
        continue;
      }

      const hashIndex = raw.indexOf('#');
      const beforeHash = hashIndex >= 0 ? raw.slice(0, hashIndex) : raw;
      const rawAnchor = hashIndex >= 0 ? raw.slice(hashIndex + 1) : '';
      const rawPath = beforeHash.split('?', 1)[0];

      refs.push({
        path: rawPath ? decodeReferenceValue(rawPath) : null,
        anchor: rawAnchor ? decodeReferenceValue(rawAnchor) : null
      });
    }
  }

  return refs;
}

function headingTextToAnchor(text) {
  const withoutImages = text.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1');
  const withoutLinks = withoutImages.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
  const withoutFormatting = withoutLinks
    .replace(/<[^>]+>/g, '')
    .replace(/[`*_~]/g, '')
    .trim()
    .toLowerCase();

  return withoutFormatting
    .replace(/[^\p{L}\p{N}\s_-]/gu, '')
    .replace(/\s+/g, '-');
}

export function extractMarkdownAnchors(markdown) {
  const anchors = new Set();
  const seen = new Map();

  for (const match of markdown.matchAll(/<a\s+[^>]*id=["']([^"']+)["'][^>]*>/gi)) {
    anchors.add(match[1]);
  }

  for (const match of markdown.matchAll(/^#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
    const base = headingTextToAnchor(match[1]);
    if (!base) {
      continue;
    }

    const count = seen.get(base) ?? 0;
    const anchor = count === 0 ? base : base + '-' + count;
    seen.set(base, count + 1);
    anchors.add(anchor);
  }

  return anchors;
}

export async function validateMarkdownAnchors(repoRoot, allowedFiles) {
  const markdownFiles = allowedFiles.filter((file) => file.endsWith('.md'));
  const anchorCache = new Map();
  const violations = [];

  async function anchorsFor(target) {
    if (!anchorCache.has(target)) {
      const markdown = await fs.readFile(path.join(repoRoot, target), 'utf8');
      anchorCache.set(target, extractMarkdownAnchors(markdown));
    }
    return anchorCache.get(target);
  }

  for (const sourcePath of markdownFiles) {
    const markdown = await fs.readFile(path.join(repoRoot, sourcePath), 'utf8');

    for (const reference of extractLocalLinkTargets(markdown)) {
      if (!reference.anchor) {
        continue;
      }

      let target = sourcePath;
      if (reference.path) {
        const resolution = await resolveReference(
          sourcePath,
          reference.path,
          repoRoot
        );
        if (resolution.status !== 'FOUND') {
          continue;
        }
        target = resolution.target;
      }

      if (!target.endsWith('.md')) {
        continue;
      }

      const anchors = await anchorsFor(target);
      if (!anchors.has(reference.anchor)) {
        violations.push({
          source: sourcePath,
          reference: (reference.path ?? '') + '#' + reference.anchor,
          target,
          reason: 'MISSING_ANCHOR'
        });
      }
    }
  }

  return violations;
}

async function buildReaderLinkGraph(repoRoot, allowedFiles) {
  const allowed = new Set(allowedFiles);
  const markdownFiles = allowedFiles.filter((file) => file.endsWith('.md'));
  const graph = new Map(markdownFiles.map((file) => [file, new Set()]));

  for (const sourcePath of markdownFiles) {
    const markdown = await fs.readFile(path.join(repoRoot, sourcePath), 'utf8');

    for (const reference of extractLocalLinkTargets(markdown)) {
      if (!reference.path) {
        continue;
      }

      const resolution = await resolveReference(
        sourcePath,
        reference.path,
        repoRoot
      );
      if (
        resolution.status === 'FOUND' &&
        resolution.target.endsWith('.md') &&
        allowed.has(resolution.target)
      ) {
        graph.get(sourcePath).add(resolution.target);
      }
    }
  }

  return graph;
}

export async function validateReaderReachability(
  repoRoot,
  allowedFiles,
  config
) {
  const graph = await buildReaderLinkGraph(repoRoot, allowedFiles);
  const roots = config.readerEntryPoints ?? ['README.md'];
  const compatibility = new Set(config.compatibilityPages ?? []);
  const requiredRoots = config.reachabilityRequiredRoots ?? [];
  const visited = new Set();
  const queue = roots.filter((root) => graph.has(root));

  while (queue.length > 0) {
    const current = queue.shift();
    if (visited.has(current)) {
      continue;
    }
    visited.add(current);

    for (const target of graph.get(current) ?? []) {
      if (!visited.has(target)) {
        queue.push(target);
      }
    }
  }

  return [...graph.keys()]
    .filter((file) =>
      requiredRoots.some(
        (root) => file === root || file.startsWith(root + '/')
      )
    )
    .filter((file) => !compatibility.has(file))
    .filter((file) => !visited.has(file))
    .map((file) => ({
      source: roots.join(','),
      reference: file,
      target: file,
      reason: 'UNREACHABLE_READER_PAGE'
    }));
}

export async function validateCompatibilityInboundLinks(
  repoRoot,
  allowedFiles,
  config
) {
  const compatibility = new Set(config.compatibilityPages ?? []);
  if (compatibility.size === 0) {
    return [];
  }

  const violations = [];

  for (const sourcePath of allowedFiles.filter((file) => file.endsWith('.md'))) {
    const markdown = await fs.readFile(path.join(repoRoot, sourcePath), 'utf8');

    for (const reference of extractLocalLinkTargets(markdown)) {
      if (!reference.path) {
        continue;
      }

      const resolution = await resolveReference(
        sourcePath,
        reference.path,
        repoRoot
      );
      if (
        resolution.status === 'FOUND' &&
        compatibility.has(resolution.target) &&
        resolution.target !== sourcePath
      ) {
        violations.push({
          source: sourcePath,
          reference: reference.path,
          target: resolution.target,
          reason: 'COMPATIBILITY_PAGE_LINKED'
        });
      }
    }
  }

  return violations;
}

function extractQuickNavigation(markdown) {
  const line = markdown
    .split('\n')
    .find((candidate) => candidate.startsWith('**Quick navigation:**'));

  if (!line) {
    return null;
  }

  const links = [];
  const linkRe = /\[([^\]]+)\]\(([^)]+)\)/g;
  for (const match of line.matchAll(linkRe)) {
    links.push({ label: match[1], reference: cleanReference(match[2]) });
  }
  return links;
}

export async function validateQuickNavigation(repoRoot, config) {
  const quickNavigation = config.quickNavigation;
  if (!quickNavigation) {
    return [];
  }

  const violations = [];
  const itemByPath = new Map(
    quickNavigation.items.map((item) => [item.path, item])
  );

  for (const surface of quickNavigation.surfaces) {
    const markdown = await fs.readFile(path.join(repoRoot, surface), 'utf8');
    const actual = extractQuickNavigation(markdown);

    if (!actual) {
      violations.push({
        source: surface,
        reference: '**Quick navigation:**',
        target: surface,
        reason: 'QUICK_NAV_MISSING'
      });
      continue;
    }

    const expected = quickNavigation.items.filter((item) => item.path !== surface);
    const resolvedActual = [];

    for (const item of actual) {
      const resolution = await resolveReference(
        surface,
        item.reference.split('#', 1)[0],
        repoRoot
      );
      resolvedActual.push({
        label: item.label,
        path: resolution.status === 'FOUND'
          ? resolution.target
          : item.reference
      });
    }

    if (resolvedActual.some((item) => item.path === surface)) {
      violations.push({
        source: surface,
        reference: '**Quick navigation:**',
        target: surface,
        reason: 'QUICK_NAV_SELF_LINK'
      });
    }

    const expectedComparable = expected.map((item) => ({
      label: item.label,
      path: item.path
    }));

    if (JSON.stringify(resolvedActual) !== JSON.stringify(expectedComparable)) {
      violations.push({
        source: surface,
        reference: JSON.stringify(resolvedActual),
        target: JSON.stringify(expectedComparable),
        reason: 'QUICK_NAV_MISMATCH'
      });
    }

    for (const item of resolvedActual) {
      if (!itemByPath.has(item.path)) {
        violations.push({
          source: surface,
          reference: item.label,
          target: item.path,
          reason: 'QUICK_NAV_UNKNOWN_TARGET'
        });
      }
    }
  }

  return violations;
}

export async function validateReaderQuality(repoRoot, allowedFiles, config) {
  return [
    ...await validateTransitiveLinks(repoRoot, allowedFiles, config),
    ...await validateMarkdownAnchors(repoRoot, allowedFiles),
    ...await validateReaderReachability(repoRoot, allowedFiles, config),
    ...await validateCompatibilityInboundLinks(repoRoot, allowedFiles, config),
    ...await validateQuickNavigation(repoRoot, config)
  ];
}

export function getSourceSha(repoRoot) {
  try {
    return execFileSync('git', ['-C', repoRoot, 'rev-parse', 'HEAD'], {
      encoding: 'utf8'
    }).trim();
  } catch {
    return process.env.GITHUB_SHA || 'UNKNOWN';
  }
}
