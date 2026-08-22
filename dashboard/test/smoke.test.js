const assert = require('assert');
const path = require('path');
const reader = require('../src/loaders/reader');
const metrics = require('../src/loaders/metrics');
const pipelineMap = require('../src/loaders/pipeline-map');
const gateStatus = require('../src/loaders/gate-status');
const { renderMetricsBar } = require('../src/tui/metrics-bar');
const { renderPipeline } = require('../src/tui/pipeline');
const { renderStateYaml } = require('../src/tui/state-yaml');
const { renderEpicQueue } = require('../src/tui/epic-queue');
const { renderFilesystem } = require('../src/tui/filesystem');
const { renderLedger } = require('../src/tui/ledger');

let passed = 0;

try {
  // Test 1: reader.readStateYaml
  const stateResult = reader.readStateYaml(path.join(__dirname, '..', '..', '..'));
  assert.ok(stateResult === null || typeof stateResult === 'object', 'readStateYaml should return null or object');
  passed++;
  console.log('  ✓ Test 1: reader.readStateYaml');
} catch (err) {
  console.error('✗ Test 1 failed:', err.message);
  process.exit(1);
}

try {
  // Test 2: metrics.computeProjectMetrics
  const metricsResult = metrics.computeProjectMetrics([
    { bcps: 3, cycleMin: 90 },
    { bcps: 2, cycleMin: 70 }
  ]);
  assert.strictEqual(metricsResult.totalBcps, 5, 'totalBcps should be 5');
  assert.strictEqual(metricsResult.totalMin, 160, 'totalMin should be 160');
  passed++;
  console.log('  ✓ Test 2: metrics.computeProjectMetrics');
} catch (err) {
  console.error('✗ Test 2 failed:', err.message);
  process.exit(1);
}

try {
  // Test 3: pipelineMap
  assert.strictEqual(pipelineMap.stepIndex('develop-tdd'), 3, 'develop-tdd should be at index 3');
  assert.strictEqual(pipelineMap.stepLabel(0), 'survey-context', 'step 0 should be survey-context');
  passed++;
  console.log('  ✓ Test 3: pipelineMap');
} catch (err) {
  console.error('✗ Test 3 failed:', err.message);
  process.exit(1);
}

try {
  // Test 4: gateStatus
  assert.strictEqual(gateStatus.gateColor('ready'), 'green', 'ready should be green');
  assert.strictEqual(gateStatus.gateColor('blocked'), 'red', 'blocked should be red');
  passed++;
  console.log('  ✓ Test 4: gateStatus');
} catch (err) {
  console.error('✗ Test 4 failed:', err.message);
  process.exit(1);
}

try {
  // Test 5: TUI render functions do not emit invalid blessed markup tags
  // Hardening against BUG-2026-06-11T160000: {dim} and {|} should never appear
  const mockBox = { content: '', setContent(c) { this.content = c; } };
  const testStateData = { activeFlow: 'test', release: { target_version: '1.0' }, gitBranch: 'main', epicCycle: { current_step: 1 } };
  const testEpics = [{ id: 'e01', title: 'Test', stories: [] }];

  renderMetricsBar(mockBox, { totalBcps: 5, totalMin: 120, avgBcpPerHour: 2.5 }, testStateData, testEpics, []);
  assert.ok(!mockBox.content.includes('{dim}') && !mockBox.content.includes('{|}'), 'metrics-bar should not contain {dim} or {|}');

  renderPipeline(mockBox, testStateData);
  assert.ok(!mockBox.content.includes('{dim}'), 'pipeline should not contain {dim}');

  renderStateYaml(mockBox, testStateData);
  assert.ok(!mockBox.content.includes('{dim}'), 'state-yaml should not contain {dim}');

  renderEpicQueue(mockBox, testEpics, null);
  assert.ok(!mockBox.content.includes('{dim}'), 'epic-queue should not contain {dim}');

  renderFilesystem(mockBox, path.join(__dirname, '..', '..', '..'));
  assert.ok(!mockBox.content.includes('{dim}'), 'filesystem should not contain {dim}');

  renderLedger(mockBox, [{ id: 's01', bcps: 3, cycleMin: 60, epic: 'e01' }]);
  assert.ok(!mockBox.content.includes('{dim}'), 'ledger should not contain {dim}');

  passed++;
  console.log('  ✓ Test 5: TUI render output does not contain invalid blessed markup tags');
} catch (err) {
  console.error('✗ Test 5 failed:', err.message);
  process.exit(1);
}

try {
  // Test 6: reader.readEpicShards with alternative keys (epic, name)
  const fs = require('fs');
  const tempProjectRoot = path.join(__dirname, 'temp_mock_project');
  const tempSpecsDir = path.join(tempProjectRoot, 'specs');
  const tempEpicsDir = path.join(tempSpecsDir, 'epics');
  
  fs.mkdirSync(tempEpicsDir, { recursive: true });
  
  const mockEpicContent = `
epic: e99
name: Mock Epic Title
stories:
  - id: e99s01
    title: Story One
`;
  fs.writeFileSync(path.join(tempEpicsDir, 'e99-mock.yaml'), mockEpicContent, 'utf8');
  
  const epicsResult = reader.readEpicShards(tempProjectRoot);
  
  // clean up
  fs.rmSync(tempProjectRoot, { recursive: true, force: true });
  
  assert.ok(Array.isArray(epicsResult) && epicsResult.length === 1, 'Should load one epic');
  assert.strictEqual(epicsResult[0].id, 'e99', 'Should map data.epic to id');
  assert.strictEqual(epicsResult[0].title, 'Mock Epic Title', 'Should map data.name to title');
  assert.strictEqual(epicsResult[0].stories.length, 1, 'Should parse stories');
  
  passed++;
  console.log('  ✓ Test 6: reader.readEpicShards with alternative keys');
} catch (err) {
  console.error('✗ Test 6 failed:', err.message);
  process.exit(1);
}

try {
  // Test 7: dashboard readers honor the configured artifact root
  const fs = require('fs');
  const os = require('os');
  const tempProjectRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'bigpowers-dashboard-'));
  const tempSpecsDir = path.join(tempProjectRoot, '.specs');
  fs.mkdirSync(path.join(tempProjectRoot, '.bigpowers'), { recursive: true });
  fs.mkdirSync(path.join(tempSpecsDir, 'epics'), { recursive: true });
  fs.writeFileSync(
    path.join(tempProjectRoot, '.bigpowers', 'config.yaml'),
    'specs_dir: .specs\nvcs: auto\n',
    'utf8'
  );
  fs.writeFileSync(
    path.join(tempSpecsDir, 'state.yaml'),
    'active_flow: planning\nactive_epic_id: e99\n',
    'utf8'
  );
  fs.writeFileSync(
    path.join(tempSpecsDir, 'epics', 'e99.yaml'),
    'id: e99\ntitle: Configured Root\nstories: []\n',
    'utf8'
  );

  const configuredState = reader.readStateYaml(tempProjectRoot);
  const configuredEpics = reader.readEpicShards(tempProjectRoot);
  const mockBox = { content: '', setContent(c) { this.content = c; } };
  renderFilesystem(mockBox, tempProjectRoot);
  fs.rmSync(tempProjectRoot, { recursive: true, force: true });

  assert.strictEqual(configuredState.activeFlow, 'planning');
  assert.strictEqual(configuredEpics[0].id, 'e99');
  assert.ok(!mockBox.content.includes('specs/ not found'));

  passed++;
  console.log('  ✓ Test 7: dashboard readers honor configured artifact root');
} catch (err) {
  console.error('✗ Test 7 failed:', err.message);
  process.exit(1);
}

console.log(`Smoke test: PASS (${passed}/7 assertions)`);
process.exit(0);
