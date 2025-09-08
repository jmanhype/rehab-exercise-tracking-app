# Smoke Test and Simulator Guide

## Quick Testing Commands

### Smoke Test
Tests basic event flow: start session → record sets → end session → fetch projection
```bash
mix rehab.smoke
# or
elixir priv/smoke/smoke.exs
```

### Data Generation
Generate realistic test data using the event simulator:
```bash
# Generate 5 patients with 14 days of history
mix rehab.seed

# Use new event simulator approach
mix rehab.seed --use-simulator --patients 10

# Generate bulk data for performance testing
mix test.load

# Generate sensor burst for Broadway testing
mix test.burst

# Generate edge cases for robustness testing
mix test.edges
```

## What the Smoke Test Does

1. **Creates a test patient** with unique UUID
2. **Starts an exercise session** (squats) with prescribed sets/reps
3. **Records 3 sets** of 10 reps each with realistic form analysis:
   - Set 1: Excellent form (0.95 quality score)
   - Set 2: Some fatigue (0.75-0.85 quality)
   - Set 3: Tired, form degrading (0.65 quality)
4. **Ends the session** with completion summary
5. **Fetches projections** to verify adherence and quality calculations
6. **Validates stream integrity** by checking event counts

## Expected Output

```
Starting Rehab Tracking Smoke Test...
Test Patient ID: 550e8400-e29b-41d4-a716-446655440000
Exercise ID: squats
Session ID: 6ba7b810-9dad-11d1-80b4-00c04fd430c8

Step 1: Starting exercise session...
✓ Session started successfully: evt_abc123

Step 2: Recording 3 sets...
✓ Recorded 30 rep observations

Step 3: Ending exercise session...
✓ Session ended successfully: evt_def456

Step 4: Fetching adherence and quality projections...
Adherence projection: {...}
Quality projection: {...}

Step 5: Verifying event stream...
✓ Retrieved 32 events from patient stream
  - ExerciseSession events: 2
  - RepObservation events: 30

✓ Event stream integrity verified
🎉 Smoke test completed successfully!
```

## Simulator Features

### Patient Profiles
- **Active Alice**: High adherence, consistent good quality
- **Struggling Sam**: Declining adherence and quality over time  
- **Consistent Carl**: Steady adherence with improving quality
- **Inconsistent Iris**: Sporadic adherence with variable quality

### Generated Events
- ✅ Exercise sessions (start/end)
- ✅ Rep observations with realistic form analysis
- ✅ Patient feedback with pain reports
- ✅ System alerts for missed sessions/poor form
- ✅ Consent tracking

### Edge Cases
- Incomplete sessions
- Poor quality sessions
- Pain reports triggering alerts
- Missed session scenarios
- Equipment failure simulation

## Performance Testing

The simulator can generate high-volume data for testing:

```bash
# Generate 100 patients with 7 days each (~10,000 events)
mix test.load

# Generate 1000 rapid sensor observations
mix test.burst
```

## File Structure

```
priv/smoke/
├── README.md          # This guide
└── smoke.exs          # Main smoke test script

lib/rehab_tracking/
└── simulator.ex       # Event simulator for test data

lib/mix/tasks/
├── rehab.seed.ex      # Enhanced seeding with simulator support
└── rehab.smoke.ex     # Smoke test runner task
```

## Error Troubleshooting

If smoke test fails:
1. Check database connectivity
2. Verify EventStore is initialized: `mix event_store.init`
3. Ensure all dependencies are installed: `mix deps.get`
4. Check application is started: `mix app.start`

For simulator errors:
1. Verify Core.Facade functions are available
2. Check event validation logic
3. Ensure UUID library is available
4. Verify event store permissions