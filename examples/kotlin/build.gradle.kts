plugins {
    kotlin("jvm") version "2.3.21"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    // protobuf messages (Java) + Kotlin DSL builders
    implementation("com.google.protobuf:protobuf-java:3.25.5")
    implementation("com.google.protobuf:protobuf-kotlin:3.25.5")
    // gRPC (Java stubs the Kotlin stubs build on, plus the Kotlin coroutine stubs)
    implementation("io.grpc:grpc-protobuf:1.62.2")
    implementation("io.grpc:grpc-stub:1.62.2")
    implementation("io.grpc:grpc-kotlin-stub:1.4.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
    // Connect for Kotlin runtime
    implementation("com.connectrpc:connect-kotlin:0.8.2")
    // javax.annotation.Generated referenced by grpc-java generated code
    compileOnly("org.apache.tomcat:annotations-api:6.0.53")
}

// Compile the buf-generated Java + Kotlin sources alongside the smoke test.
sourceSets["main"].java.srcDir("../../gen/kotlin")

kotlin {
    jvmToolchain(21)
    sourceSets["main"].kotlin.srcDir("../../gen/kotlin")
}

application {
    mainClass.set("examples.SmokeKt")
}
