package main

import (
	"strings"
	"testing"
)

func TestConfigRead(t *testing.T) {
	const perl_exe = `c:/Program Files/Git/usr/bin/perl.exe`
	sample := `{
		"handler":{
			".pl":"` + perl_exe + `"
		}
	}`
	var config Config
	err := config.Read(strings.NewReader(sample))
	if err != nil {
		t.Fatal(err.Error())
	}
	val, ok := config.Handler[".pl"]
	if !ok {
		t.Fatal(".pl not found")
	}
	if val != perl_exe {
		t.Fatalf(".pl -> %s invalid: expected: %s", val, perl_exe)
	}
}
