scalaVersion := "2.13.14"

scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked",
  "-Xfatal-warnings",
  "-language:reflectiveCalls",
)

// Chisel 6.5.0
val chiselVersion = "6.5.0"
addCompilerPlugin("org.chipsalliance" %  "chisel-plugin" %
  chiselVersion cross CrossVersion.full)
libraryDependencies += "org.chipsalliance" %% "chisel" %
  chiselVersion
libraryDependencies += "edu.berkeley.cs" %% "chiseltest" %
  "6.0.0"