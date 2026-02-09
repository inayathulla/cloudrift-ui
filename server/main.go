package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// API server that wraps the Cloudrift CLI for web frontend access.

// ---------------------------------------------------------------------------
// Terraform job management
// ---------------------------------------------------------------------------

var (
	tfMutex  sync.Mutex
	tfJobs   = make(map[string]*TerraformJob)
	tfJobsMu sync.Mutex
)

// TerraformJob tracks the state of an async terraform plan generation.
type TerraformJob struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	Phase     string    `json:"phase"`
	Output    string    `json:"output"`
	PlanPath  string    `json:"plan_path"`
	Error     string    `json:"error"`
	StartedAt time.Time `json:"started_at"`
	DoneAt    time.Time `json:"done_at,omitempty"`
}

func main() {
	port := os.Getenv("API_PORT")
	if port == "" {
		port = "8081"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/scan", corsMiddleware(handleScan))
	mux.HandleFunc("/api/health", corsMiddleware(handleHealth))
	mux.HandleFunc("/api/version", corsMiddleware(handleVersion))
	mux.HandleFunc("/api/config", corsMiddleware(handleConfig))
	mux.HandleFunc("/api/files/plan", corsMiddleware(handlePlanFile))
	mux.HandleFunc("/api/files/list", corsMiddleware(handleFileList))
	mux.HandleFunc("/api/files/upload", corsMiddleware(handleFileUpload))
	mux.HandleFunc("/api/files/generate-plan", corsMiddleware(handleGeneratePlan))
	mux.HandleFunc("/api/terraform/status", corsMiddleware(handleTerraformStatus))
	mux.HandleFunc("/api/terraform/upload", corsMiddleware(handleTerraformUpload))
	mux.HandleFunc("/api/terraform/plan", corsMiddleware(handleTerraformPlan))
	mux.HandleFunc("/api/terraform/job", corsMiddleware(handleTerraformJob))

	// Periodically clean up completed terraform jobs older than 1 hour
	go func() {
		ticker := time.NewTicker(10 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			cutoff := time.Now().Add(-1 * time.Hour)
			tfJobsMu.Lock()
			for id, job := range tfJobs {
				if !job.DoneAt.IsZero() && job.DoneAt.Before(cutoff) {
					delete(tfJobs, id)
				}
			}
			tfJobsMu.Unlock()
		}
	}()

	log.Printf("Cloudrift API server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next(w, r)
	}
}

func cliPath() string {
	if p := os.Getenv("CLOUDRIFT_CLI_PATH"); p != "" {
		return p
	}
	return "cloudrift"
}

func workDir() string {
	if d := os.Getenv("CLOUDRIFT_WORK_DIR"); d != "" {
		return d
	}
	return ""
}

// safePath resolves a relative path against the work directory and ensures
// it does not escape via ".." traversal.
func safePath(relPath string) (string, error) {
	wd := workDir()
	if wd == "" {
		wd = "."
	}
	cleaned := filepath.Clean(relPath)
	if filepath.IsAbs(cleaned) {
		return "", fmt.Errorf("absolute paths not allowed: %s", relPath)
	}
	full := filepath.Join(wd, cleaned)
	absWd, _ := filepath.Abs(wd)
	absFull, _ := filepath.Abs(full)
	if !strings.HasPrefix(absFull, absWd) {
		return "", fmt.Errorf("path escapes working directory: %s", relPath)
	}
	return full, nil
}

type scanRequest struct {
	Service      string `json:"service"`
	ConfigPath   string `json:"config_path"`
	PolicyDir    string `json:"policy_dir,omitempty"`
	SkipPolicies bool   `json:"skip_policies,omitempty"`
}

func handleScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req scanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	if req.Service == "" {
		jsonError(w, "service is required", http.StatusBadRequest)
		return
	}
	if req.ConfigPath == "" {
		req.ConfigPath = "config/cloudrift.yml"
	}

	args := []string{
		"scan",
		"--config=" + req.ConfigPath,
		"--service=" + req.Service,
		"--format=json",
		"--no-emoji",
	}
	if req.PolicyDir != "" {
		args = append(args, "--policy-dir="+req.PolicyDir)
	}
	if req.SkipPolicies {
		args = append(args, "--skip-policies")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, cliPath(), args...)
	if wd := workDir(); wd != "" {
		cmd.Dir = wd
	}

	output, err := cmd.CombinedOutput()
	outStr := string(output)

	// Exit code 2 = policy violations found (valid output)
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 2 {
			// Valid scan with violations — extract JSON
		} else {
			jsonError(w, "Scan failed: "+outStr, http.StatusInternalServerError)
			return
		}
	}

	// Extract JSON from CLI output (CLI prints status lines before JSON)
	jsonStr := extractJSON(outStr)
	if jsonStr == "" {
		jsonError(w, "No JSON output from CLI: "+outStr, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprint(w, jsonStr)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	cmd := exec.Command(cliPath(), "scan", "--help")
	err := cmd.Run()
	available := err == nil

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"available": available})
}

func handleVersion(w http.ResponseWriter, r *http.Request) {
	cmd := exec.Command(cliPath(), "--version")
	output, err := cmd.Output()
	if err != nil {
		jsonError(w, "CLI not available", http.StatusServiceUnavailable)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"version": strings.TrimSpace(string(output)),
	})
}

// ---------------------------------------------------------------------------
// Config file endpoints (GET/PUT)
// ---------------------------------------------------------------------------

func handleConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		handleConfigGet(w, r)
	case http.MethodPut:
		handleConfigPut(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleConfigGet(w http.ResponseWriter, r *http.Request) {
	configPath := r.URL.Query().Get("path")
	if configPath == "" {
		configPath = "config/cloudrift.yml"
	}
	fullPath, err := safePath(configPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	data, err := os.ReadFile(fullPath)
	if err != nil {
		jsonError(w, "Config not found: "+configPath, http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/yaml")
	w.Write(data)
}

func handleConfigPut(w http.ResponseWriter, r *http.Request) {
	configPath := r.URL.Query().Get("path")
	if configPath == "" {
		configPath = "config/cloudrift.yml"
	}
	fullPath, err := safePath(configPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 64*1024))
	if err != nil {
		jsonError(w, "Failed to read body: "+err.Error(), http.StatusBadRequest)
		return
	}
	if err := os.WriteFile(fullPath, body, 0644); err != nil {
		jsonError(w, "Failed to write config: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ---------------------------------------------------------------------------
// Plan file endpoints (GET/PUT)
// ---------------------------------------------------------------------------

func handlePlanFile(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		handlePlanGet(w, r)
	case http.MethodPut:
		handlePlanPut(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handlePlanGet(w http.ResponseWriter, r *http.Request) {
	planPath := r.URL.Query().Get("path")
	if planPath == "" {
		planPath = "examples/plan.json"
	}
	fullPath, err := safePath(planPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	data, err := os.ReadFile(fullPath)
	if err != nil {
		jsonError(w, "Plan file not found: "+planPath, http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(data)
}

func handlePlanPut(w http.ResponseWriter, r *http.Request) {
	planPath := r.URL.Query().Get("path")
	if planPath == "" {
		planPath = "examples/plan.json"
	}
	fullPath, err := safePath(planPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 10*1024*1024))
	if err != nil {
		jsonError(w, "Failed to read body: "+err.Error(), http.StatusBadRequest)
		return
	}
	if !json.Valid(body) {
		jsonError(w, "Invalid JSON content", http.StatusBadRequest)
		return
	}
	if err := os.WriteFile(fullPath, body, 0644); err != nil {
		jsonError(w, "Failed to write plan: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ---------------------------------------------------------------------------
// File listing endpoint
// ---------------------------------------------------------------------------

func handleFileList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	wd := workDir()
	if wd == "" {
		wd = "."
	}

	type fileInfo struct {
		Path string `json:"path"`
		Name string `json:"name"`
		Size int64  `json:"size"`
	}
	result := struct {
		Configs []fileInfo `json:"configs"`
		Plans   []fileInfo `json:"plans"`
	}{
		Configs: []fileInfo{},
		Plans:   []fileInfo{},
	}

	filepath.Walk(filepath.Join(wd, "config"), func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if strings.HasSuffix(info.Name(), ".yml") || strings.HasSuffix(info.Name(), ".yaml") {
			relPath, _ := filepath.Rel(wd, path)
			result.Configs = append(result.Configs, fileInfo{
				Path: relPath, Name: info.Name(), Size: info.Size(),
			})
		}
		return nil
	})

	filepath.Walk(filepath.Join(wd, "examples"), func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if strings.HasSuffix(info.Name(), ".json") {
			relPath, _ := filepath.Rel(wd, path)
			result.Plans = append(result.Plans, fileInfo{
				Path: relPath, Name: info.Name(), Size: info.Size(),
			})
		}
		return nil
	})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// ---------------------------------------------------------------------------
// File upload endpoint (multipart)
// ---------------------------------------------------------------------------

func handleFileUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 10*1024*1024)
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		jsonError(w, "File too large or invalid form", http.StatusBadRequest)
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, "Missing file field: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer file.Close()

	if !strings.HasSuffix(header.Filename, ".json") {
		jsonError(w, "Only .json files are allowed", http.StatusBadRequest)
		return
	}

	data, err := io.ReadAll(file)
	if err != nil {
		jsonError(w, "Failed to read file: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if !json.Valid(data) {
		jsonError(w, "Uploaded file is not valid JSON", http.StatusBadRequest)
		return
	}

	destPath := filepath.Join("examples", filepath.Base(header.Filename))
	fullPath, err := safePath(destPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := os.WriteFile(fullPath, data, 0644); err != nil {
		jsonError(w, "Failed to save file: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
		"path":   destPath,
		"name":   header.Filename,
	})
}

// ---------------------------------------------------------------------------
// Generate plan endpoint
// ---------------------------------------------------------------------------

func handleGeneratePlan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Service string                 `json:"service"`
		Plan    map[string]interface{} `json:"plan"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}
	if req.Plan == nil {
		jsonError(w, "plan is required", http.StatusBadRequest)
		return
	}

	// Write plan JSON to examples/generated-plan.json
	planBytes, err := json.MarshalIndent(req.Plan, "", "  ")
	if err != nil {
		jsonError(w, "Failed to marshal plan: "+err.Error(), http.StatusInternalServerError)
		return
	}

	planPath := "examples/generated-plan.json"
	fullPlanPath, err := safePath(planPath)
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := os.WriteFile(fullPlanPath, planBytes, 0644); err != nil {
		jsonError(w, "Failed to write plan: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Update the matching config file's plan_path
	configFile := "config/cloudrift.yml"
	if strings.EqualFold(req.Service, "ec2") {
		configFile = "config/cloudrift-ec2.yml"
	}
	fullConfigPath, err := safePath(configFile)
	if err == nil {
		configData, readErr := os.ReadFile(fullConfigPath)
		if readErr == nil {
			// Simple YAML update: replace the plan_path line
			lines := strings.Split(string(configData), "\n")
			updated := false
			for i, line := range lines {
				if strings.HasPrefix(strings.TrimSpace(line), "plan_path:") {
					lines[i] = "plan_path: ./examples/generated-plan.json"
					updated = true
					break
				}
			}
			if !updated {
				lines = append(lines, "plan_path: ./examples/generated-plan.json")
			}
			os.WriteFile(fullConfigPath, []byte(strings.Join(lines, "\n")), 0644)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "ok",
		"plan_path": planPath,
		"config":    configFile,
	})
}

// ---------------------------------------------------------------------------
// Terraform endpoints
// ---------------------------------------------------------------------------

func terraformPath() string {
	if p := os.Getenv("TERRAFORM_PATH"); p != "" {
		return p
	}
	return "terraform"
}

// GET /api/terraform/status — Check Terraform availability and list .tf files.
func handleTerraformStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	cmd := exec.Command(terraformPath(), "version", "-json")
	versionOutput, versionErr := cmd.Output()
	available := versionErr == nil

	var version string
	if available {
		var vInfo map[string]interface{}
		if json.Unmarshal(versionOutput, &vInfo) == nil {
			version, _ = vInfo["terraform_version"].(string)
		}
	}

	tfDir := filepath.Join(workDir(), "terraform")
	tfFiles := []string{}
	if entries, err := os.ReadDir(tfDir); err == nil {
		for _, e := range entries {
			if !e.IsDir() && strings.HasSuffix(e.Name(), ".tf") {
				tfFiles = append(tfFiles, e.Name())
			}
		}
	}

	_, initErr := os.Stat(filepath.Join(tfDir, ".terraform"))
	initialized := initErr == nil

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"available":   available,
		"version":     version,
		"tf_files":    tfFiles,
		"has_files":   len(tfFiles) > 0,
		"initialized": initialized,
		"tf_dir":      "terraform/",
	})
}

// POST /api/terraform/upload — Upload .tf and .tfvars files.
func handleTerraformUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 50*1024*1024)
	if err := r.ParseMultipartForm(50 << 20); err != nil {
		jsonError(w, "File too large or invalid form", http.StatusBadRequest)
		return
	}

	tfDir := filepath.Join(workDir(), "terraform")
	os.MkdirAll(tfDir, 0755)

	uploaded := []string{}
	for _, fileHeaders := range r.MultipartForm.File {
		for _, fh := range fileHeaders {
			if !strings.HasSuffix(fh.Filename, ".tf") && !strings.HasSuffix(fh.Filename, ".tfvars") {
				jsonError(w, "Only .tf and .tfvars files allowed: "+fh.Filename, http.StatusBadRequest)
				return
			}
			safeName := filepath.Base(fh.Filename)
			file, err := fh.Open()
			if err != nil {
				jsonError(w, "Failed to read file: "+err.Error(), http.StatusInternalServerError)
				return
			}
			data, readErr := io.ReadAll(file)
			file.Close()
			if readErr != nil {
				jsonError(w, "Failed to read file data: "+readErr.Error(), http.StatusInternalServerError)
				return
			}
			if err := os.WriteFile(filepath.Join(tfDir, safeName), data, 0644); err != nil {
				jsonError(w, "Failed to save file: "+err.Error(), http.StatusInternalServerError)
				return
			}
			uploaded = append(uploaded, safeName)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":   "ok",
		"uploaded": uploaded,
		"tf_dir":   "terraform/",
	})
}

// POST /api/terraform/plan — Start async terraform plan generation.
func handleTerraformPlan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if !tfMutex.TryLock() {
		jsonError(w, "Another Terraform operation is already running", http.StatusConflict)
		return
	}

	tfDir := filepath.Join(workDir(), "terraform")
	entries, err := os.ReadDir(tfDir)
	if err != nil {
		tfMutex.Unlock()
		jsonError(w, "Terraform directory not found. Upload .tf files first.", http.StatusBadRequest)
		return
	}
	hasTf := false
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".tf") {
			hasTf = true
			break
		}
	}
	if !hasTf {
		tfMutex.Unlock()
		jsonError(w, "No .tf files found. Upload Terraform files first.", http.StatusBadRequest)
		return
	}

	jobID := fmt.Sprintf("tf-%d", time.Now().UnixMilli())
	job := &TerraformJob{
		ID:        jobID,
		Status:    "pending",
		Phase:     "Starting...",
		StartedAt: time.Now(),
	}

	tfJobsMu.Lock()
	tfJobs[jobID] = job
	tfJobsMu.Unlock()

	go runTerraformPipeline(job, tfDir)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "started",
		"job_id": jobID,
	})
}

func runTerraformPipeline(job *TerraformJob, tfDir string) {
	defer tfMutex.Unlock()

	tf := terraformPath()
	var outputBuf strings.Builder

	// Step 1: terraform init (10 min timeout — downloads providers)
	job.Status = "init"
	job.Phase = "Running terraform init..."
	initCtx, initCancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer initCancel()
	initCmd := exec.CommandContext(initCtx, tf, "init", "-no-color", "-input=false")
	initCmd.Dir = tfDir
	initOutput, initErr := initCmd.CombinedOutput()
	outputBuf.Write(initOutput)
	outputBuf.WriteByte('\n')
	job.Output = outputBuf.String()
	if initErr != nil {
		job.Status = "error"
		job.Error = "terraform init failed: " + initErr.Error()
		job.Phase = "Init failed"
		job.DoneAt = time.Now()
		return
	}

	// Step 2: terraform plan (10 min timeout)
	job.Status = "plan"
	job.Phase = "Running terraform plan..."
	planBinaryPath := filepath.Join(tfDir, "tfplan.binary")
	planCtx, planCancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer planCancel()
	planCmd := exec.CommandContext(planCtx, tf, "plan", "-out="+planBinaryPath, "-no-color", "-input=false")
	planCmd.Dir = tfDir
	planOutput, planErr := planCmd.CombinedOutput()
	outputBuf.Write(planOutput)
	outputBuf.WriteByte('\n')
	job.Output = outputBuf.String()
	if planErr != nil {
		job.Status = "error"
		job.Error = "terraform plan failed: " + planErr.Error()
		job.Phase = "Plan failed"
		job.DoneAt = time.Now()
		return
	}

	// Step 3: terraform show -json (5 min timeout)
	job.Status = "show"
	job.Phase = "Converting plan to JSON..."
	showCtx, showCancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer showCancel()
	showCmd := exec.CommandContext(showCtx, tf, "show", "-json", "-no-color", planBinaryPath)
	showCmd.Dir = tfDir
	showOutput, showErr := showCmd.CombinedOutput()
	if showErr != nil {
		job.Status = "error"
		job.Error = "terraform show failed: " + showErr.Error()
		job.Phase = "Show failed"
		job.DoneAt = time.Now()
		return
	}

	if !json.Valid(showOutput) {
		job.Status = "error"
		job.Error = "terraform show produced invalid JSON"
		job.Phase = "Invalid output"
		job.DoneAt = time.Now()
		return
	}

	// Step 4: Save plan.json
	planJsonPath := "examples/terraform-plan.json"
	fullPlanPath, pathErr := safePath(planJsonPath)
	if pathErr != nil {
		job.Status = "error"
		job.Error = "Path error: " + pathErr.Error()
		job.DoneAt = time.Now()
		return
	}
	if err := os.WriteFile(fullPlanPath, showOutput, 0644); err != nil {
		job.Status = "error"
		job.Error = "Failed to save plan JSON: " + err.Error()
		job.DoneAt = time.Now()
		return
	}

	// Step 5: Update config
	configFile := "config/cloudrift.yml"
	fullConfigPath, _ := safePath(configFile)
	if configData, readErr := os.ReadFile(fullConfigPath); readErr == nil {
		lines := strings.Split(string(configData), "\n")
		updated := false
		for i, line := range lines {
			if strings.HasPrefix(strings.TrimSpace(line), "plan_path:") {
				lines[i] = "plan_path: ./examples/terraform-plan.json"
				updated = true
				break
			}
		}
		if !updated {
			lines = append(lines, "plan_path: ./examples/terraform-plan.json")
		}
		os.WriteFile(fullConfigPath, []byte(strings.Join(lines, "\n")), 0644)
	}

	job.Status = "completed"
	job.Phase = "Plan generated successfully"
	job.PlanPath = planJsonPath
	job.DoneAt = time.Now()

	// Clean up binary plan file
	os.Remove(planBinaryPath)
}

// GET /api/terraform/job?id=<job_id> — Poll job status.
func handleTerraformJob(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	jobID := r.URL.Query().Get("id")
	if jobID == "" {
		jsonError(w, "job id is required", http.StatusBadRequest)
		return
	}

	tfJobsMu.Lock()
	job, exists := tfJobs[jobID]
	tfJobsMu.Unlock()

	if !exists {
		jsonError(w, "Job not found: "+jobID, http.StatusNotFound)
		return
	}

	elapsed := time.Since(job.StartedAt).Seconds()
	if !job.DoneAt.IsZero() {
		elapsed = job.DoneAt.Sub(job.StartedAt).Seconds()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":        job.ID,
		"status":    job.Status,
		"phase":     job.Phase,
		"error":     job.Error,
		"plan_path": job.PlanPath,
		"elapsed_s": int(elapsed),
		"output":    job.Output,
	})
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func extractJSON(output string) string {
	start := strings.Index(output, "{")
	if start == -1 {
		return ""
	}
	end := strings.LastIndex(output, "}")
	if end == -1 || end <= start {
		return ""
	}
	return output[start : end+1]
}

func jsonError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
