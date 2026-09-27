import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  collectAllowedFiles,
  copyPublication,
  getSourceSha,
  loadConfig,
  validateReaderQuality
} from './publication-lib.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(scriptDir, '..');
const repoRoot = path.resolve(webRoot, '..');
const configPath = path.join(webRoot, 'config', 'publication.json');
const outputRoot = path.join(webRoot, '.generated', 'publication');
const publicRoot = path.join(outputRoot, 'public');
const reportPath = path.join(webRoot, '.generated', 'publication-report.json');

const config = await loadConfig(configPath);
const allowedFiles = await collectAllowedFiles(repoRoot, config);
const violations = await validateReaderQuality(repoRoot, allowedFiles, config);
const sourceSha = getSourceSha(repoRoot);

const report = {
  schemaVersion: 1,
  sourceSha,
  generatedAt: new Date().toISOString(),
  publishedFileCount: allowedFiles.length,
  publishedFiles: allowedFiles,
  violations
};

await fs.mkdir(path.dirname(reportPath), { recursive: true });
await fs.writeFile(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

if (violations.length > 0) {
  console.error(JSON.stringify(report, null, 2));
  process.exitCode = 1;
} else {
  await copyPublication(repoRoot, outputRoot, publicRoot, allowedFiles);
  console.log(
    `Publication snapshot ready: ${allowedFiles.length} files from ${sourceSha}`
  );
}
