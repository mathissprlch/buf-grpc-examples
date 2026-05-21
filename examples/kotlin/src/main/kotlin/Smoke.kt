package examples

import com.greet.v1.GreetServiceClient
import com.greet.v1.GreetServiceGrpcKt
import com.greet.v1.greetRequest

// Exercises all three Kotlin generators: the protobuf Kotlin DSL, the gRPC
// coroutine stubs, and the Connect client. Building + running this proves the
// generated code is valid and links against its runtimes.
fun main() {
    val request = greetRequest { name = "Kotlin" }
    check(request.name == "Kotlin") { "unexpected name: ${request.name}" }

    val grpcServiceName = GreetServiceGrpcKt.SERVICE_NAME
    check(grpcServiceName == "greet.v1.GreetService") { grpcServiceName }

    // Reference the Connect-generated client type to prove it links.
    val connectClient = GreetServiceClient::class.simpleName

    println(
        "kotlin codegen ok: name=${request.name}, " +
            "grpc=$grpcServiceName, connect=$connectClient",
    )
}
