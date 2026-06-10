# Gifthealth Pharmacy System - Prescription Report Generator

## Project Overview

This project implements a prescription event processing system for a pharmacy that generates financial reports based on prescription fill and return events. The system processes a stream of prescription events and produces a summary report showing each patient's total fills and income.

## Requirements

The program accepts an input file via command-line argument or stdin containing space-delimited prescription events in the format:

```
PatientName DrugName EventType
```

### Event Types

1. **created** - Initializes a prescription in the system. A prescription must be created before any fills or returns can be applied.
2. **filled** - Records a prescription fill. Each fill generates $5 income.
3. **returned** - Records a prescription return. A return cancels a prior fill and incurs a $1 loss. Because it also reverses the previously counted $5 fill income, the effective income impact of processing a return is -$6.

### Key Rules

- Events that occur before a prescription is `created` are silently ignored.
- A prescription can be filled multiple times.
- A prescription can be returned multiple times, as long as each return corresponds to a prior valid fill (the prompt guarantees this condition).
- The implementation guards against invalid return operations for robustness.
- The report includes only patients with at least one `created` event.

## Assumptions / Clarifications

- Each `(patient, drug)` pair is treated as a single prescription.
- The prompt guarantees that multiple `created` events will not occur for the same prescription.
- Although the prompt states that a `returned` event causes a `$1 loss`, the provided sample output only matches if a return both:
  - reverses the previously counted `$5` fill income, and
  - applies an additional `$1` loss.
- Therefore, the implementation treats a return as:
  - **-1 fill**
  - **-$6 income effective impact**
- Events before `created` are discarded as required by the prompt.

## Architecture & Design

### Overview

The system follows a layered architecture with clear separation of concerns:

```
Command-Line Interface (bin/prescription_report)
        ↓
PharmacySystem (orchestrates event processing)
        ↓
Patient (manages patient data)
        ↓
Prescription (models individual prescriptions)
```

### Core Components

#### 1. **Event** (`lib/gifthealth/event.rb`)
- **Purpose**: Data object representing a single prescription event
- **Responsibility**: 
  - Parse raw text input into structured event objects
  - Validate event types
  - Provide immutable event data (frozen)
- **Design Decision**: Used a factory pattern for parsing to keep event creation logic centralized and testable

#### 2. **Prescription** (`lib/gifthealth/prescription.rb`)
- **Purpose**: Models a single prescription for a specific drug
- **Responsibility**:
  - Track prescription creation state
  - Manage fill count (incremented on fills, decremented on returns)
  - Validate state transitions (e.g., prevent fills before creation)
- **Key Methods**:
  - `create`: Marks prescription as created
  - `fill`: Increments fill count if prescription is created
  - `return_fill`: Decrements fill count if fills are available
- **Design Decision**: Encapsulates prescription logic, making it independent of patient context and easier to test

#### 3. **Patient** (`lib/gifthealth/patient.rb`)
- **Purpose**: Manages all prescriptions for a single patient and tracks financial metrics
- **Responsibility**:
  - Route events to the appropriate prescription
  - Track cumulative income
  - Calculate total fills across all prescriptions
- **Key Methods**:
  - `process_event`: Routes events to prescriptions and updates income accordingly
  - `total_fills`: Sums fills across all prescriptions
- **Design Decision**: Separates patient-level concerns from prescription-level concerns

#### 4. **PharmacySystem** (`lib/gifthealth/pharmacy_system.rb`)
- **Purpose**: Main orchestrator for the entire system
- **Responsibility**:
  - Parse input stream and create events
  - Route events to appropriate patients
  - Ensure only patients with `created` events are tracked
- **Key Methods**:
  - `process_stream`: Processes an input stream line by line
- **Design Decision**: Acts as a façade, simplifying the interface for the report generator

#### 5. **Report** (`lib/gifthealth/report.rb`)
- **Purpose**: Generates the final report output
- **Responsibility**:
  - Format and output patient data
  - Ensure patients are sorted by name for consistent output
- **Design Decision**: Separated report generation from system logic for testability and flexibility

### Data Flow

1. User invokes program with input file
2. `PharmacySystem` reads input stream line by line
3. Each line is parsed into an `Event` via `Event::Factory`
4. Events are routed to the appropriate `Patient`
5. `Patient` updates `Prescription` state and income based on event type
6. `Report` generates sorted output from final system state

### Thought Process & Architecture Decisions

#### Why Layered Architecture?
I chose a layered architecture (Command → System → Patient → Prescription → Report) because it mirrors the natural hierarchical structure of the domain:
- **PharmacySystem** is the entry point, managing the entire workflow
- **Patient** aggregates data at a patient level
- **Prescription** represents the atomic unit of business logic

This hierarchy provides natural boundaries for responsibility and makes the code easier to reason about. Each layer has a clear input/output contract, making it testable in isolation.

#### Why Event Factory Pattern?
Event creation is the only point where we parse raw user input. By centralizing this in `Event::Factory`, I achieved:
- **Single source of truth** for validation logic
- **Easy to test** - validate parsing independently of system logic
- **Extensible** - if validation rules change, only one place needs updating
- **Separation of concerns** - Event class doesn't know about parsing details

#### Why Separate Patient & Prescription Classes?
I could have flattened this into a single Patient class tracking everything directly. Instead, I separated concerns:
- **Prescription** handles state per drug (created?, fill_count)
- **Patient** aggregates prescriptions and income

**Why this matters:**
- A patient might have multiple prescriptions for different drugs
- Each prescription has independent state (one can be created while another isn't)
- Testing is easier - can test prescription logic without patient context
- Future extensibility - if we need drug-specific reports, Prescription is already isolated

#### Why Track Income in Patient, Not Prescription?
Income is patient-level, not prescription-level. While each prescription contributes to income, the patient owns the financial data. This makes the Report layer simple - it only needs to query Patient, not aggregate across Prescriptions.

#### Data Structures Used
- **Hash (patients dictionary)**: O(1) lookup by patient name
- **Hash (prescriptions dictionary per patient)**: O(1) lookup by drug name
- **Integer counters**: Efficient tracking of fill_count and income
- **Frozen objects**: Event objects are frozen for safety

These choices prioritize lookup performance and simplicity over memory - justified for a single-pass batch process.

### Design Tradeoffs

#### 1. **Income Calculation: Net Effect of Returns**
- **Decision**: The effective impact of a return is a $6 reduction in income ($5 reversal + $1 loss)
- **Why**: The specification states that each return results in a $1 loss AND cancels a prior fill (+$5). The provided sample output only matches if we combine these effects: -$5 (removing the previous fill income) + -$1 (loss penalty) = -$6 net impact.
- **Rationale**: This interpretation matches the official expected output for all test cases and makes business sense - a return both removes the fill revenue AND incurs a penalty.
- **Code Impact**: The `Patient#process_event` method applies -$6 for every return, regardless of future fills.
- **Tradeoff**: Could implement this as separate -$5 and -$1 operations, but combining them is clearer and matches the business logic.

#### 2. **Ignored Pre-Creation Events**
- **Decision**: Events before a prescription is `created` are silently ignored without warning
- **Why**: The spec explicitly requires this behavior. It prevents invalid state transitions and keeps the system simple.
- **Rationale**: Silently ignoring is cleaner than throwing errors or logging warnings for expected data anomalies. The system focuses on valid events only.
- **Code Impact**: `PharmacySystem#process_event` checks if a patient exists before processing non-creation events.
- **Tradeoff**: Alternative would be to log warnings or reject the entire file on invalid input. Silent filtering was chosen for robustness - the spec guarantees this won't happen with valid input.
- **Assumption**: Pre-creation events represent data errors, not intentional edge cases.

#### 3. **Patient Creation Timing**
- **Decision**: Patients are only instantiated in the system when a `created` event is encountered
- **Why**: Prevents cluttering the report with phantom patients who have no valid prescriptions. The report should only show patients with actual business activity.
- **Rationale**: This acts as a natural filter - invalid events create no patient record, so the final report is clean and accurate.
- **Code Impact**: `PharmacySystem#find_or_create_patient` only creates Patient objects on `created` events.
- **Tradeoff**: Could load all patients upfront or eagerly create on any event. Instead, we lazily create only when needed, reducing memory footprint.
- **Assumption**: Only patients with `created` events should appear in the output report.

#### 4. **Prescription Per Drug**
- **Decision**: Each (patient, drug) combination is a separate prescription object
- **Why**: Drugs are independent entities. Patient A taking Drug X should be tracked separately from Patient A taking Drug Y. This allows precise auditing per drug.
- **Rationale**: Better business analytics - can see which drugs have high return rates, which patients are frequent fillers, etc. Also matches real pharmacy systems.
- **Code Impact**: `Patient` maintains a hash of `Prescription` objects keyed by drug name.
- **Tradeoff**: Could aggregate all fills by patient only. But per-drug tracking is more useful and only slightly more complex.
- **Assumption**: The spec guarantees multiple `created` events won't occur for the same (patient, drug) pair.

#### 5. **Immutable Events**
- **Decision**: Event objects are frozen immediately after creation
- **Why**: Events represent historical facts from the input stream. Once created, they should never change. Freezing prevents accidental mutations.
- **Rationale**: Improves code safety - frozen objects can't be accidentally modified, making the system more predictable and testable.
- **Code Impact**: `Event#initialize` calls `freeze` at the end.
- **Tradeoff**: Tiny performance overhead from freezing. Worth it for safety in a production system.
- **Philosophy**: Immutable data = fewer bugs, easier reasoning about program state.

## Testing Strategy

### Test Organization

```
spec/
  ├── integration_spec.rb        # System-level tests
  ├── spec_helper.rb             # Test configuration
  └── gifthealth/
      ├── event_spec.rb          # Event parsing tests
      ├── patient_spec.rb        # Patient logic tests
      └── prescription_spec.rb   # Prescription state tests
```

### Test Coverage

1. **Unit Tests**:
   - **Prescription**: Creation, filling, returning, and state validation
   - **Patient**: Event processing, income calculation, fill counting
   - **Event**: Parsing, validation, and factory pattern

2. **Integration Tests**:
   - End-to-end system behavior with sample data
   - Edge cases: events before creation, multiple returns, multiple patients
   - Filtering: ensures patients without `created` events don't appear in report


### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/gifthealth/patient_spec.rb

# Run with verbose output
bundle exec rspec -v

# Run with failure details
bundle exec rspec --format documentation
```

## Code Quality

### Code Organization Philosophy

The codebase is organized following these principles:

**1. Organizational Hierarchy**
- `lib/gifthealth/` contains all domain logic - separated from the command-line interface
- `bin/prescription_report` is the thin CLI wrapper - handles I/O, delegates to domain
- `lib/gifthealth/` follows a "low to high abstraction" order:
  - `event.rb` - lowest level, raw data from input
  - `prescription.rb` - single entity logic
  - `patient.rb` - aggregates prescriptions
  - `pharmacy_system.rb` - orchestrates everything
  - `report.rb` - final output formatting

**2. Why Separate bin from lib?**
The CLI is just presentation logic. By separating it from domain logic:
- Domain logic is testable without forking processes
- Easy to add web/API interfaces later without duplicating logic
- Clearer boundaries between concerns

**3. Dependency Flow**
```
PharmacySystem
  ↓ uses
Event + Patient
  ↓ uses
Prescription

Report
  ↓ reads from
PharmacySystem
```
This is a **one-way dependency flow** - high-level classes depend on lower-level ones, never the reverse. This makes code modular and testable.

**4. Method Organization Within Classes**
- **Public methods first**: What clients care about
- **Private methods last**: Internal implementation details
- **attr_reader grouped at top**: Data contracts visible immediately

### Principles Applied

1. **Single Responsibility**: Each class has one reason to change
2. **Encapsulation**: Private methods hide implementation details
3. **Immutability**: Events are frozen after creation
4. **Composition**: Patient composes Prescriptions, PharmacySystem composes Patients
5. **Factory Pattern**: Event::Factory centralizes parsing logic
6. **Separation of Concerns**: Report generation is independent of system logic

### Code Style

- Ruby style guide compliance
- Frozen string literals enabled
- Comprehensive comments for complex logic
- Descriptive variable and method names
- No cyclomatic complexity issues

## Running the Program

### Installation

```bash
# Install dependencies
bundle install
```

### Usage

```bash
# From a file
./bin/prescription_report input.txt

# From stdin
cat input.txt | ./bin/prescription_report

# Output to file
./bin/prescription_report input.txt > output.txt
```



## Execution Instructions

### Prerequisites
- Ruby 2.7+ installed
- Bundler installed (`gem install bundler`)

### Setup

```bash
# Navigate to project directory
cd Gifthealth\ Engineering\ Test\ Project

# Install dependencies
bundle install
```

### Run Program

```bash
# Run with file input
./bin/prescription_report sample_input.txt

# Run with piped input
echo -e "Nick A created\nMark B created" | ./bin/prescription_report

# Save output to file
./bin/prescription_report sample_input.txt > report.txt
```

### Run Tests

```bash
# Run all tests
bundle exec rspec

# Run with verbose output
bundle exec rspec -v

# Run specific test file
bundle exec rspec spec/gifthealth/patient_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```




## File Structure

```
.
├── bin/
│   └── prescription_report      # Executable entry point
├── lib/
│   └── gifthealth/
│       ├── event.rb             # Event model and factory
│       ├── patient.rb           # Patient model
│       ├── pharmacy_system.rb   # Main orchestrator
│       ├── prescription.rb      # Prescription model
│       └── report.rb            # Report generator
├── spec/
│   ├── gifthealth/
│   │   ├── event_spec.rb
│   │   ├── patient_spec.rb
│   │   └── prescription_spec.rb
│   ├── integration_spec.rb
│   └── spec_helper.rb
├── Gemfile                      # Ruby dependencies
├── README.md                    # This file
└── sample_input.txt             # Example input data
```

