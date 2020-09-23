import Foundation
import TuistCore

public final class AutogeneratedProjectSchemeGraphMapper: GraphMapping {
    public init() {}

    public func map(graph: Graph) throws -> (Graph, [SideEffectDescriptor]) {
        guard let project = graph.entryNodes
            .compactMap({ $0 as? TargetNode })
            .first?
            .project
        else { return (graph, []) }

        let targetNodes = graph.targets.values.flatMap { $0 }
        let targets = targetNodes
            .filter { !$0.target.product.testsBundle }
            .map { TargetReference(projectPath: $0.project.path, name: $0.name) }
        let testableTargets = targetNodes
            .filter(\.target.product.testsBundle)
            .map { TargetReference(projectPath: $0.project.path, name: $0.name) }
            .map { TestableTarget(target: $0) }

        let scheme = Scheme(
            name: "\(graph.name)-Project",
            buildAction: BuildAction(targets: targets),
            testAction: TestAction(
                targets: testableTargets,
                arguments: nil,
                configurationName: project.defaultDebugBuildConfigurationName,
                coverage: false,
                codeCoverageTargets: [],
                preActions: [],
                postActions: [],
                diagnosticsOptions: Set()
            )
        )

        return (graph.with(schemes: graph.schemes + [scheme]), [])
    }
}