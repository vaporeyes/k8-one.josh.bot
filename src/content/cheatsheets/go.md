---
title: "Go"
description: "Quick reference for Go syntax, patterns, modules, and common standard library usage."
updatedDate: 2026-03-30
---

## Project Setup

```bash
# Initialize module
go mod init github.com/user/project

# Add dependency
go get github.com/lib/pq@latest

# Tidy (remove unused, add missing)
go mod tidy

# Vendor dependencies
go mod vendor

# Run
go run .
go run ./cmd/api

# Build
go build -o bin/server ./cmd/api

# Test
go test ./...
go test -v -run TestGetUser ./internal/service/
go test -count=1 ./...           # skip cache
go test -race ./...              # race detector
go test -cover ./...             # coverage

# Lint / vet
go vet ./...
```

## Variables and Types

```go
// Declaration
var name string = "hello"
var count int                     // zero value: 0
name := "hello"                   // short declaration

// Constants
const maxRetries = 3
const (
    StatusActive   = "active"
    StatusInactive = "inactive"
)

// Iota
const (
    ReadPerm  = 1 << iota         // 1
    WritePerm                     // 2
    ExecPerm                      // 4
)

// Type aliases and definitions
type UserID int64
type Handler func(w http.ResponseWriter, r *http.Request)
```

## Structs

```go
type User struct {
    ID        int64     `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email,omitempty"`
    CreatedAt time.Time `json:"created_at"`
}

// Constructor pattern
func NewUser(name, email string) *User {
    return &User{
        Name:      name,
        Email:     email,
        CreatedAt: time.Now(),
    }
}

// Methods
func (u *User) FullName() string {
    return u.Name
}

// Embedding (composition)
type Admin struct {
    User
    Level int
}
```

## Interfaces

```go
type Store interface {
    GetUser(ctx context.Context, id int64) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}

// Implicit satisfaction (no "implements" keyword)
type PostgresStore struct {
    db *sql.DB
}

func (s *PostgresStore) GetUser(ctx context.Context, id int64) (*User, error) {
    // ...
}

// Common interfaces
type Stringer interface {
    String() string
}

type Reader interface {
    Read(p []byte) (n int, err error)
}

// Type assertion
val, ok := i.(string)

// Type switch
switch v := i.(type) {
case string:
    fmt.Println("string:", v)
case int:
    fmt.Println("int:", v)
default:
    fmt.Println("unknown")
}
```

## Error Handling

```go
// Return errors
func GetUser(id int64) (*User, error) {
    if id <= 0 {
        return nil, fmt.Errorf("invalid id: %d", id)
    }
    // ...
}

// Check errors
user, err := GetUser(42)
if err != nil {
    return fmt.Errorf("get user: %w", err)  // wrap with context
}

// Custom errors
type NotFoundError struct {
    Resource string
    ID       int64
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s %d not found", e.Resource, e.ID)
}

// errors.Is / errors.As
if errors.Is(err, sql.ErrNoRows) {
    // ...
}

var nfe *NotFoundError
if errors.As(err, &nfe) {
    fmt.Println(nfe.Resource)
}

// Sentinel errors
var ErrNotFound = errors.New("not found")
```

## Slices and Maps

```go
// Slices
nums := []int{1, 2, 3}
nums = append(nums, 4, 5)
sub := nums[1:3]                  // [2, 3]
length := len(nums)

// Make with capacity
buf := make([]byte, 0, 1024)

// Copy
dst := make([]int, len(src))
copy(dst, src)

// Maps
m := map[string]int{
    "a": 1,
    "b": 2,
}
m["c"] = 3
delete(m, "a")

// Check existence
val, ok := m["key"]
if !ok {
    // key not present
}

// Iterate
for k, v := range m {
    fmt.Println(k, v)
}

// Slices package (1.21+)
slices.Sort(nums)
slices.Contains(nums, 3)
idx := slices.Index(nums, 2)

// Maps package (1.21+)
keys := maps.Keys(m)
maps.Copy(dst, src)
```

## Control Flow

```go
// If with init statement
if err := doThing(); err != nil {
    return err
}

// Switch (no fallthrough by default)
switch status {
case "active":
    activate()
case "inactive", "disabled":
    deactivate()
default:
    log.Println("unknown status")
}

// For (the only loop)
for i := 0; i < 10; i++ { }
for i, v := range items { }
for k, v := range myMap { }
for { /* infinite */ }
for condition { /* while */ }

// Defer (LIFO)
f, err := os.Open("file.txt")
if err != nil {
    return err
}
defer f.Close()

// Select (channel multiplexing)
select {
case msg := <-ch:
    handle(msg)
case <-ctx.Done():
    return ctx.Err()
case <-time.After(5 * time.Second):
    return errors.New("timeout")
}
```

## Goroutines and Channels

```go
// Launch goroutine
go func() {
    doWork()
}()

// Channels
ch := make(chan string)            // unbuffered
ch := make(chan string, 10)        // buffered

ch <- "hello"                      // send
msg := <-ch                        // receive
close(ch)                          // close

// Range over channel
for msg := range ch {
    process(msg)
}

// WaitGroup
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item string) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()

// Mutex
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()
// ... critical section

// Once
var once sync.Once
once.Do(func() {
    // runs exactly once
})

// errgroup
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error {
    return fetchData(ctx)
})
if err := g.Wait(); err != nil {
    return err
}
```

## Context

```go
// Background (top-level)
ctx := context.Background()

// With timeout
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

// With cancel
ctx, cancel := context.WithCancel(ctx)

// With value (use sparingly)
ctx = context.WithValue(ctx, keyRequestID, "abc123")
reqID := ctx.Value(keyRequestID).(string)

// Check cancellation
select {
case <-ctx.Done():
    return ctx.Err()
default:
}
```

## HTTP

```go
// Simple server
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", getUser)
mux.HandleFunc("POST /users", createUser)
http.ListenAndServe(":8080", mux)

// Handler function (1.22+ pattern)
func getUser(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(user)
}

// HTTP client
client := &http.Client{Timeout: 10 * time.Second}
resp, err := client.Get("https://api.example.com/data")
if err != nil {
    return err
}
defer resp.Body.Close()

body, err := io.ReadAll(resp.Body)
```

## JSON

```go
// Marshal (struct to JSON)
data, err := json.Marshal(user)
data, err := json.MarshalIndent(user, "", "  ")

// Unmarshal (JSON to struct)
var user User
err := json.Unmarshal(data, &user)

// Decoder (from reader)
err := json.NewDecoder(r.Body).Decode(&user)

// Encoder (to writer)
json.NewEncoder(w).Encode(user)

// Raw JSON
var raw json.RawMessage
```

## String Formatting

```go
fmt.Sprintf("name: %s", name)       // string
fmt.Sprintf("count: %d", count)     // integer
fmt.Sprintf("pi: %.2f", 3.14159)    // float
fmt.Sprintf("val: %v", anything)    // default format
fmt.Sprintf("type: %T", val)        // type name
fmt.Sprintf("struct: %+v", user)    // struct with field names
fmt.Sprintf("hex: %x", bytes)       // hex encoding
fmt.Sprintf("quoted: %q", str)      // quoted string
```

## Testing

```go
func TestGetUser(t *testing.T) {
    user, err := GetUser(1)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "alice" {
        t.Errorf("got %q, want %q", user.Name, "alice")
    }
}

// Table-driven tests
func TestValidate(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  bool
    }{
        {"empty", "", false},
        {"valid", "hello", true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Validate(tt.input)
            if got != tt.want {
                t.Errorf("Validate(%q) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}

// Test helper
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}
```

## Useful Patterns

```go
// Functional options
type Option func(*Server)

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func NewServer(opts ...Option) *Server {
    s := &Server{port: 8080}
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Graceful shutdown
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
defer stop()
go func() { srv.ListenAndServe() }()
<-ctx.Done()
srv.Shutdown(context.Background())
```
