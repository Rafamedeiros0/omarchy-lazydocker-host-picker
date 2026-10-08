package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	pluginID    = "rafamedeiros.lazydocker-host-picker"
	defaultKey  = "SUPER + SHIFT + D"
	blockStart  = "-- BEGIN LAZYDOCKER HOST PICKER (managed)"
	blockEnd    = "-- END LAZYDOCKER HOST PICKER (managed)"
	menuEntryID = "trigger.lazydocker-picker"
)

var (
	legacyBinding = regexp.MustCompile(`(?m)^-- Route Omarchy's Docker shortcut to the host picker\.[^\n]*\n-- dispatcher runs Omarchy's original ` + "`omarchy-launch-docker-tui`" + ` command\.[^\n]*\nhl\.unbind\("SUPER \+ SHIFT \+ D"\)\no\.bind\("SUPER \+ SHIFT \+ D", "Docker host picker", "[^"]*lazydocker-picker-shortcut"\)\n?`)
	managedBlock  = regexp.MustCompile(`(?ms)^\s*` + regexp.QuoteMeta(blockStart) + `\n.*?^` + regexp.QuoteMeta(blockEnd) + `\s*\n?`)
	managedKey    = regexp.MustCompile(`hl\.unbind\("([^"]+)"\)`)
	menuOwnedRow  = regexp.MustCompile(`(?m)^\s*// Managed by Lazydocker Host Picker\.\n\s*"trigger\.lazydocker-picker"\s*:\s*\{[^\n]*\}\s*,?\s*\n`)
)

type configPaths struct {
	bindings   string
	state      string
	backup     string
	menu       string
	dispatcher string
}

type bindInfo struct {
	Key         string `json:"key"`
	Modmask     int    `json:"modmask"`
	Description string `json:"description"`
}

type conflictInfo struct {
	Description string `json:"description"`
	Key         string `json:"key"`
}

type shortcutState struct {
	Enabled      bool   `json:"enabled"`
	Shortcut     string `json:"shortcut,omitempty"`
	LastShortcut string `json:"lastShortcut,omitempty"`
}

func paths() configPaths {
	home, _ := os.UserHomeDir()
	if value := os.Getenv("HOME"); value != "" {
		home = value
	}
	return configPaths{
		bindings:   envOr("LAZYDOCKER_BINDINGS", filepath.Join(home, ".config/hypr/bindings.lua")),
		state:      envOr("LAZYDOCKER_SHORTCUT_STATE", filepath.Join(home, ".config/omarchy/lazydocker-host-picker-shortcut.json")),
		backup:     envOr("LAZYDOCKER_BINDINGS_BACKUP", filepath.Join(home, ".local/state/omarchy/lazydocker-host-picker/bindings.lua.original")),
		menu:       envOr("LAZYDOCKER_MENU", filepath.Join(home, ".config/omarchy/extensions/omarchy-menu.jsonc")),
		dispatcher: envOr("LAZYDOCKER_DISPATCHER", filepath.Join(home, ".local/bin/lazydocker-picker-shortcut")),
	}
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func canonicalKey(value string) (string, error) {
	parts := strings.FieldsFunc(strings.ToUpper(value), func(r rune) bool { return r == '+' })
	clean := make([]string, 0, len(parts))
	seen := make(map[string]bool)
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if seen[part] {
			return "", errors.New("duplicate shortcut modifier or key")
		}
		seen[part] = true
		clean = append(clean, part)
	}
	key := ""
	for _, part := range clean {
		if !isModifier(part) {
			if key != "" {
				return "", errors.New("use modifiers plus one key, for example SUPER + SHIFT + D")
			}
			key = part
		}
	}
	if key == "" || !supportedKey(key) {
		return "", errors.New("that key is not supported by the shortcut editor")
	}
	mods := make([]string, 0, 4)
	for _, name := range []string{"SUPER", "CTRL", "ALT", "SHIFT"} {
		if seen[name] {
			mods = append(mods, name)
		}
	}
	if len(mods) == 0 {
		return "", errors.New("a shortcut must include at least one modifier")
	}
	return strings.Join(append(mods, key), " + "), nil
}

func isModifier(value string) bool {
	return value == "SUPER" || value == "CTRL" || value == "ALT" || value == "SHIFT"
}

func supportedKey(key string) bool {
	if len(key) == 1 && ((key[0] >= 'A' && key[0] <= 'Z') || (key[0] >= '0' && key[0] <= '9')) {
		return true
	}
	if strings.HasPrefix(key, "F") {
		var n int
		if _, err := fmt.Sscanf(key, "F%d", &n); err == nil && n >= 1 && n <= 12 && key == fmt.Sprintf("F%d", n) {
			return true
		}
	}
	switch key {
	case "SPACE", "TAB", "ESCAPE", "RETURN", "BACKSPACE", "DELETE", "INSERT", "HOME", "END",
		"PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT", "COMMA", "PERIOD", "SLASH",
		"SEMICOLON", "APOSTROPHE", "BRACKETLEFT", "BRACKETRIGHT", "MINUS", "EQUAL", "BACKSLASH", "GRAVE":
		return true
	}
	return false
}

func readText(path string) (string, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	return string(data), err
}

func atomicWrite(path, text string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	mode := os.FileMode(0o644)
	if info, err := os.Stat(path); err == nil {
		mode = info.Mode().Perm()
	}
	file, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".*")
	if err != nil {
		return err
	}
	tmp := file.Name()
	defer os.Remove(tmp)
	if _, err = io.WriteString(file, text); err == nil {
		err = file.Sync()
	}
	if closeErr := file.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	if err = os.Chmod(tmp, mode); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func currentKey(text string) string {
	if match := managedBlock.FindString(text); match != "" {
		parts := managedKey.FindStringSubmatch(match)
		if len(parts) == 2 {
			return parts[1]
		}
	}
	if legacyBinding.MatchString(text) {
		return defaultKey
	}
	return ""
}

func stripBindings(text string) string {
	text = managedBlock.ReplaceAllString(text, "")
	text = legacyBinding.ReplaceAllString(text, "")
	return text
}

func makeManagedBlock(key, dispatcher string) string {
	return fmt.Sprintf("%s\nhl.unbind(%q)\no.bind(%q, %q, %q)\n%s", blockStart, key, key, "Lazydocker Picker", dispatcher, blockEnd)
}

func runHyprctl(args ...string) (string, error) {
	command := exec.Command("hyprctl", args...)
	output, err := command.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("hyprctl %s: %s", strings.Join(args, " "), strings.TrimSpace(string(output)))
	}
	return strings.TrimSpace(string(output)), nil
}

func reloadAndValidate() error {
	if _, err := runHyprctl("reload"); err != nil {
		return err
	}
	errorsText, err := runHyprctl("configerrors")
	if err != nil {
		return err
	}
	if errorsText != "" && !strings.EqualFold(errorsText, "no config errors found") && errorsText != "[]" {
		return fmt.Errorf("Hyprland reported config errors: %s", errorsText)
	}
	return nil
}

func getConflicts(key string, paths configPaths) ([]conflictInfo, error) {
	mask, keyName := keyParts(key)
	output, err := runHyprctl("-j", "binds")
	if err != nil {
		return nil, fmt.Errorf("could not inspect active Hyprland shortcuts: %w", err)
	}
	var binds []bindInfo
	if err := json.Unmarshal([]byte(output), &binds); err != nil {
		return nil, fmt.Errorf("could not parse active Hyprland shortcuts: %w", err)
	}
	text, err := readText(paths.bindings)
	if err != nil {
		return nil, err
	}
	activeKey := currentKey(text)
	var found []conflictInfo
	for _, bind := range binds {
		if bind.Modmask != mask || !strings.EqualFold(bind.Key, keyName) {
			continue
		}
		if activeKey == key && (bind.Description == "Lazydocker Picker" || bind.Description == "Docker host picker") {
			continue
		}
		description := bind.Description
		if description == "" {
			description = "Other shortcut"
		}
		found = append(found, conflictInfo{Description: description, Key: bind.Key})
	}
	return found, nil
}

func keyParts(key string) (int, string) {
	parts := strings.Split(key, " + ")
	mask := 0
	for _, part := range parts[:len(parts)-1] {
		switch part {
		case "SHIFT":
			mask |= 1
		case "CTRL":
			mask |= 4
		case "ALT":
			mask |= 8
		case "SUPER":
			mask |= 64
		}
	}
	return mask, parts[len(parts)-1]
}

func loadState(path string) shortcutState {
	data, err := os.ReadFile(path)
	if err != nil {
		return shortcutState{}
	}
	var state shortcutState
	_ = json.Unmarshal(data, &state)
	return state
}

func saveState(path string, state shortcutState) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return atomicWrite(path, string(data)+"\n")
}

func setKey(rawKey string, allowConflict bool, p configPaths) (map[string]any, error) {
	key, err := canonicalKey(rawKey)
	if err != nil {
		return nil, err
	}
	conflicts, err := getConflicts(key, p)
	if err != nil {
		return nil, err
	}
	if len(conflicts) != 0 && !allowConflict {
		labels := make([]string, len(conflicts))
		for i, item := range conflicts {
			labels[i] = item.Description
		}
		return nil, fmt.Errorf("%s is already assigned to %s; confirm replacement first", key, strings.Join(labels, ", "))
	}
	original, err := readText(p.bindings)
	if err != nil {
		return nil, err
	}
	if original != "" {
		if _, err := os.Stat(p.backup); errors.Is(err, os.ErrNotExist) {
			if err := atomicWrite(p.backup, original); err != nil {
				return nil, fmt.Errorf("could not back up bindings: %w", err)
			}
		}
	}
	text := strings.TrimRight(stripBindings(original), " \t\r\n")
	if text != "" {
		text += "\n\n"
	}
	text += makeManagedBlock(key, p.dispatcher) + "\n"
	if err := atomicWrite(p.bindings, text); err != nil {
		return nil, err
	}
	if err := reloadAndValidate(); err != nil {
		_ = atomicWrite(p.bindings, original)
		_, _ = runHyprctl("reload")
		return nil, err
	}
	state := loadState(p.state)
	state.Enabled = true
	state.Shortcut = key
	state.LastShortcut = key
	if err := saveState(p.state, state); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true, "enabled": true, "shortcut": key, "lastShortcut": key}, nil
}

func resetKey(p configPaths) (map[string]any, error) {
	original, err := readText(p.bindings)
	if err != nil {
		return nil, err
	}
	text := strings.TrimRight(stripBindings(original), " \t\r\n")
	if text != "" {
		text += "\n"
	}
	if err := atomicWrite(p.bindings, text); err != nil {
		return nil, err
	}
	if err := reloadAndValidate(); err != nil {
		_ = atomicWrite(p.bindings, original)
		_, _ = runHyprctl("reload")
		return nil, err
	}
	state := loadState(p.state)
	last := state.Shortcut
	if last == "" {
		last = state.LastShortcut
	}
	if last == "" {
		last = defaultKey
	}
	if err := saveState(p.state, shortcutState{Enabled: false, LastShortcut: last}); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true, "enabled": false, "shortcut": nil, "lastShortcut": last, "restored": "Omarchy default"}, nil
}

func getStatus(p configPaths) map[string]any {
	text, _ := readText(p.bindings)
	key := currentKey(text)
	state := loadState(p.state)
	if key == "" && state.Enabled {
		key = state.Shortcut
	}
	last := state.LastShortcut
	if last == "" {
		last = key
	}
	if last == "" {
		last = defaultKey
	}
	return map[string]any{"ok": true, "enabled": key != "", "shortcut": nullableString(key), "lastShortcut": last}
}

func nullableString(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func stripJSONC(text string) string {
	var out strings.Builder
	quoted, escaped := false, false
	for i := 0; i < len(text); {
		if quoted {
			c := text[i]
			out.WriteByte(c)
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == '"' {
				quoted = false
			}
			i++
			continue
		}
		if text[i] == '"' {
			quoted = true
			out.WriteByte(text[i])
			i++
		} else if strings.HasPrefix(text[i:], "//") {
			if end := strings.IndexByte(text[i:], '\n'); end >= 0 {
				i += end
			} else {
				break
			}
		} else if strings.HasPrefix(text[i:], "/*") {
			if end := strings.Index(text[i+2:], "*/"); end >= 0 {
				i += end + 4
			} else {
				break
			}
		} else {
			out.WriteByte(text[i])
			i++
		}
	}
	return out.String()
}

func parseMenu(text string) (map[string]json.RawMessage, error) {
	clean := stripJSONC(text)
	clean = regexp.MustCompile(`,\s*([}\]])`).ReplaceAllString(clean, "$1")
	var menu map[string]json.RawMessage
	if err := json.Unmarshal([]byte(clean), &menu); err != nil {
		return nil, fmt.Errorf("Omarchy menu extension is not valid JSONC: %w", err)
	}
	if menu == nil {
		return nil, errors.New("Omarchy menu extension must be a JSON object")
	}
	return menu, nil
}

func rootCloseIndex(text string) int {
	depth := 0
	quoted, escaped := false, false
	for i := 0; i < len(text); i++ {
		c := text[i]
		if quoted {
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == '"' {
				quoted = false
			}
			continue
		}
		if c == '"' {
			quoted = true
		} else if strings.HasPrefix(text[i:], "//") {
			if end := strings.IndexByte(text[i:], '\n'); end >= 0 {
				i += end
			} else {
				return -1
			}
		} else if strings.HasPrefix(text[i:], "/*") {
			if end := strings.Index(text[i+2:], "*/"); end >= 0 {
				i += end + 3
			} else {
				return -1
			}
		} else if c == '{' {
			depth++
		} else if c == '}' {
			depth--
			if depth == 0 {
				return i
			}
		}
	}
	return -1
}

func menuAdd(p configPaths) (map[string]any, error) {
	text, err := readText(p.menu)
	if err != nil {
		return nil, err
	}
	if text == "" {
		text = "{}\n"
	}
	menu, err := parseMenu(text)
	if err != nil {
		return nil, err
	}
	if existing, ok := menu[menuEntryID]; ok {
		var item map[string]any
		_ = json.Unmarshal(existing, &item)
		if strings.Contains(text, "// Managed by Lazydocker Host Picker.") && item["label"] == "Lazydocker Picker" && strings.Contains(fmt.Sprint(item["action"]), pluginID) {
			return map[string]any{"ok": true, "menu": "Trigger > Lazydocker Picker", "alreadyPresent": true}, nil
		}
		return nil, errors.New("the Omarchy menu already has an entry named Lazydocker Picker; leaving it unchanged")
	}
	pos := rootCloseIndex(text)
	if pos < 0 {
		return nil, errors.New("could not find the Omarchy menu's closing brace")
	}
	prefix := text[:pos]
	cleanPrefix := strings.TrimSpace(stripJSONC(prefix))
	comma := ""
	if cleanPrefix != "" && !strings.HasSuffix(cleanPrefix, ",") {
		comma = ","
	}
	entry := fmt.Sprintf("\n  // Managed by Lazydocker Host Picker.\n  %q: {\"icon\":\"󰒍\",\"label\":\"Lazydocker Picker\",\"action\":%q},\n", menuEntryID, "omarchy-shell shell toggle "+pluginID+" '{}'")
	updated := strings.TrimRight(prefix, " \t\r\n") + comma + entry + text[pos:]
	if _, err := parseMenu(updated); err != nil {
		return nil, err
	}
	if err := atomicWrite(p.menu, updated); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true, "menu": "Trigger > Lazydocker Picker"}, nil
}

func menuRemove(p configPaths) (map[string]any, error) {
	text, err := readText(p.menu)
	if err != nil {
		return nil, err
	}
	updated, count := replaceFirst(menuOwnedRow, text, "")
	if count > 0 {
		if _, err := parseMenu(updated); err != nil {
			return nil, err
		}
		if err := atomicWrite(p.menu, updated); err != nil {
			return nil, err
		}
	}
	return map[string]any{"ok": true, "removed": count > 0}, nil
}

func replaceFirst(re *regexp.Regexp, value, replacement string) (string, int) {
	loc := re.FindStringIndex(value)
	if loc == nil {
		return value, 0
	}
	return value[:loc[0]] + replacement + value[loc[1]:], 1
}

func run(args []string) (map[string]any, error) {
	p := paths()
	if len(args) == 0 {
		return nil, errors.New("usage: lazydocker-picker-integration status|check KEY|set KEY [--replace]|reset|menu-add|menu-remove|enable|disable")
	}
	switch args[0] {
	case "status":
		return getStatus(p), nil
	case "check":
		if len(args) != 2 {
			return nil, errors.New("usage: check KEY")
		}
		key, err := canonicalKey(args[1])
		if err != nil {
			return nil, err
		}
		found, err := getConflicts(key, p)
		if err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "shortcut": key, "conflicts": found}, nil
	case "set":
		if len(args) < 2 || len(args) > 3 || (len(args) == 3 && args[2] != "--replace") {
			return nil, errors.New("usage: set KEY [--replace]")
		}
		return setKey(args[1], len(args) == 3, p)
	case "reset", "disable":
		return resetKey(p)
	case "enable":
		state := getStatus(p)
		key, _ := state["lastShortcut"].(string)
		if key == "" {
			key = defaultKey
		}
		return setKey(key, true, p)
	case "menu-add":
		return menuAdd(p)
	case "menu-remove":
		return menuRemove(p)
	default:
		return nil, fmt.Errorf("unknown command %q", args[0])
	}
}

func main() {
	result, err := run(os.Args[1:])
	if err != nil {
		writeJSON(map[string]any{"ok": false, "error": err.Error()})
		os.Exit(1)
	}
	writeJSON(result)
}

func writeJSON(value any) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}
