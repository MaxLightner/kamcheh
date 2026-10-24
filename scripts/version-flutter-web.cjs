// Each deployment serves a unique Flutter entry bundle. GitHub Pages and
// returning browsers can otherwise keep the previous accounting UI cached.
const fs = require('node:fs');
const path = require('node:path');

const release = (process.env.GITHUB_SHA || '').slice(0, 12);
if (!/^[0-9a-f]{12}$/.test(release)) {
  throw new Error('A Git commit SHA is required to version the Flutter build.');
}

const buildDir = path.join('build', 'web');
const mainFile = 'main.dart.js';
const fingerprinted = `main.${release}.dart.js`;
fs.copyFileSync(path.join(buildDir, mainFile), path.join(buildDir, fingerprinted));

const bootstrapPath = path.join(buildDir, 'flutter_bootstrap.js');
const bootstrap = fs.readFileSync(bootstrapPath, 'utf8');
const nextBootstrap = bootstrap.replaceAll(mainFile, fingerprinted);
if (nextBootstrap === bootstrap) {
  throw new Error('Flutter bootstrap did not contain the expected JS entrypoint.');
}
fs.writeFileSync(bootstrapPath, nextBootstrap);

const indexPath = path.join(buildDir, 'index.html');
const index = fs.readFileSync(indexPath, 'utf8');
const nextIndex = index.replace(
  'src="flutter_bootstrap.js"',
  `src="flutter_bootstrap.js?v=${release}"`,
);
if (index === nextIndex) {
  throw new Error('Flutter HTML did not contain the expected bootstrap tag.');
}
fs.writeFileSync(indexPath, nextIndex);
console.log(`Versioned Flutter app assets for ${release}`);
