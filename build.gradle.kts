plugins {
    id("tech.harmonysoft.oss.gradle.release.paperwork") version "1.11.0"
}

releasePaperwork {
    projectVersionFile.set("pubspec.yaml")
    projectVersionRegex.set("version:\\s*([^\\s]+)")
}