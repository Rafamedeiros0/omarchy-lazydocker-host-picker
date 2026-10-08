package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCanonicalKey(t *testing.T) {
	got, err := canonicalKey("shift + d + super")
	if err != nil || got != "SUPER + SHIFT + D" {
		t.Fatalf("canonicalKey() = %q, %v", got, err)
	}
	for _, invalid := range []string{"D", "SUPER + D + F", "SUPER + SUPER + D"} {
		if _, err := canonicalKey(invalid); err == nil {
			t.Errorf("canonicalKey(%q) unexpectedly succeeded", invalid)
		}
	}
}

func TestSetResetPreservesUnrelatedHyprlandConfig(t *testing.T) {
	tmp := t.TempDir()
	paths := configPaths{
		bindings:   filepath.Join(tmp, "bindings.lua"),
		state:      filepath.Join(tmp, "shortcut.json"),
		backup:     filepath.Join(tmp, "bindings.original"),
		dispatcher: filepath.Join(tmp, "dispatcher"),
	}
	before := "-- user's config\no.bind(\"SUPER + X\", \"Personal action\", \"echo personal\")\n"
	if err := os.WriteFile(paths.bindings, []byte(before), 0o644); err != nil {
		t.Fatal(err)
	}
	installFakeHyprctl(t, tmp, `[]`)
	t.Setenv("PATH", tmp+string(os.PathListSeparator)+os.Getenv("PATH"))
	if _, err := setKey("SUPER + SHIFT + F12", false, paths); err != nil {
		t.Fatal(err)
	}
	updated, _ := os.ReadFile(paths.bindings)
	if !strings.Contains(string(updated), before) || !strings.Contains(string(updated), `hl.unbind("SUPER + SHIFT + F12")`) {
		t.Fatalf("managed binding did not preserve user config:\n%s", updated)
	}
	if _, err := resetKey(paths); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(paths.bindings)
	if string(after) != before {
		t.Fatalf("reset changed unrelated config:\nwant %q\n got %q", before, after)
	}
	state := loadState(paths.state)
	if state.Enabled {
		t.Fatal("reset left shortcut enabled")
	}
}

func TestSetRejectsConflictingKeyUnlessConfirmed(t *testing.T) {
	tmp := t.TempDir()
	paths := configPaths{
		bindings:   filepath.Join(tmp, "bindings.lua"),
		state:      filepath.Join(tmp, "shortcut.json"),
		backup:     filepath.Join(tmp, "backup"),
		dispatcher: filepath.Join(tmp, "dispatcher"),
	}
	before := "-- user config\n"
	if err := os.WriteFile(paths.bindings, []byte(before), 0o644); err != nil {
		t.Fatal(err)
	}
	installFakeHyprctl(t, tmp, `[{"key":"F12","modmask":65,"description":"Personal action"}]`)
	t.Setenv("PATH", tmp+string(os.PathListSeparator)+os.Getenv("PATH"))
	if _, err := setKey("SUPER + SHIFT + F12", false, paths); err == nil || !strings.Contains(err.Error(), "Personal action") {
		t.Fatalf("expected a conflict error, got %v", err)
	}
	unchanged, _ := os.ReadFile(paths.bindings)
	if string(unchanged) != before {
		t.Fatal("conflict check changed the user's bindings")
	}
}

func TestMenuAddRemovePreservesJSONC(t *testing.T) {
	tmp := t.TempDir()
	menuPath := filepath.Join(tmp, "omarchy-menu.jsonc")
	before := "{\n  // keep this note\n  \"trigger\": {\"label\": \"Trigger\"},\n}\n"
	if err := os.WriteFile(menuPath, []byte(before), 0o644); err != nil {
		t.Fatal(err)
	}
	p := configPaths{menu: menuPath}
	if _, err := menuAdd(p); err != nil {
		t.Fatal(err)
	}
	added, _ := os.ReadFile(menuPath)
	parsed, err := parseMenu(string(added))
	if err != nil {
		t.Fatal(err)
	}
	var item map[string]any
	if err := json.Unmarshal(parsed[menuEntryID], &item); err != nil {
		t.Fatal(err)
	}
	if item["label"] != "Lazydocker Picker" || !strings.Contains(string(added), "// keep this note") {
		t.Fatalf("menu entry incorrect or user comment lost: %s", added)
	}
	if _, err := menuRemove(p); err != nil {
		t.Fatal(err)
	}
	removed, _ := os.ReadFile(menuPath)
	if strings.Contains(string(removed), menuEntryID) || !strings.Contains(string(removed), "// keep this note") {
		t.Fatalf("menu removal disturbed content: %s", removed)
	}
}

func TestMenuAddDoesNotReplaceExistingEntry(t *testing.T) {
	tmp := t.TempDir()
	menuPath := filepath.Join(tmp, "menu.jsonc")
	before := `{"trigger.lazydocker-picker":{"label":"My item"}}`
	if err := os.WriteFile(menuPath, []byte(before), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := menuAdd(configPaths{menu: menuPath}); err == nil {
		t.Fatal("menuAdd unexpectedly replaced a pre-existing entry")
	}
	after, _ := os.ReadFile(menuPath)
	if string(after) != before {
		t.Fatalf("pre-existing menu entry was modified: %s", after)
	}
}

func installFakeHyprctl(t *testing.T, dir, bindsJSON string) {
	t.Helper()
	path := filepath.Join(dir, "hyprctl")
	script := "#!/bin/sh\ncase \"$*\" in\n  '-j binds') printf '%s\\n' '" + bindsJSON + "' ;;\n  reload) printf 'ok\\n' ;;\n  configerrors) ;;\n  *) exit 0 ;;\nesac\n"
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
}
