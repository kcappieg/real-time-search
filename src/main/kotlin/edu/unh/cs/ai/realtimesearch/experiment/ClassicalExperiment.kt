package edu.unh.cs.ai.realtimesearch.experiment

import edu.unh.cs.ai.realtimesearch.MetronomeException
import edu.unh.cs.ai.realtimesearch.environment.Action
import edu.unh.cs.ai.realtimesearch.environment.Domain
import edu.unh.cs.ai.realtimesearch.environment.State
import edu.unh.cs.ai.realtimesearch.experiment.configuration.GeneralExperimentConfiguration
import edu.unh.cs.ai.realtimesearch.experiment.configuration.realtime.TerminationType
import edu.unh.cs.ai.realtimesearch.experiment.configuration.realtime.TerminationType.EXPANSION
import edu.unh.cs.ai.realtimesearch.experiment.configuration.realtime.TerminationType.TIME
import edu.unh.cs.ai.realtimesearch.experiment.result.ExperimentResult
import edu.unh.cs.ai.realtimesearch.logging.info
import edu.unh.cs.ai.realtimesearch.planner.classical.ClassicalPlanner
import org.slf4j.LoggerFactory

/**
 * An experiments meant for classical search, such as depth first search.
 * An single run means requesting the planner to return a plan given an initial state.
 *
 * You can either run experiments on a specific state, or have them randomly
 * generated by the domain.
 *
 * NOTE: assumes the same domain is used to create both the planner as this class
 *
 * @param planner is the planner that is involved in the experiment
 * @param domain is the domain of the planner. Used for random state generation
 * @param initialState is the start state of the planner.
 */
class ClassicalExperiment<StateType : State<StateType>>(val configuration: GeneralExperimentConfiguration,
                                                        val planner: ClassicalPlanner<StateType>,
                                                        val domain: Domain<StateType>,
                                                        val initialState: StateType) : Experiment() {

    private val logger = LoggerFactory.getLogger(ClassicalExperiment::class.java)
    private var actions: List<Action> = emptyList()

    override fun run(): ExperimentResult {
        // do experiment on state, either given or randomly created
        val state: StateType = initialState
        //        logger.warn { "Starting experiment with state $state on planner $planner" }

        val cpuNanoTime = measureThreadCpuNanoTime {
            actions = planner.plan(state)
        }

        val planningTime: Long = when (TerminationType.valueOf(configuration.terminationType)) {
            TIME -> cpuNanoTime
            EXPANSION -> planner.expandedNodeCount.toLong()
            else -> throw MetronomeException("Unknown termination type")
        }

        // log results
        val pathLength = actions.size.toLong()
        logger.info { "Path length: [$pathLength] After ${planner.expandedNodeCount} expanded and ${planner.generatedNodeCount} generated nodes" }

        return ExperimentResult(
                configuration = configuration.valueStore,
                expandedNodes = planner.expandedNodeCount,
                generatedNodes = planner.generatedNodeCount,
                planningTime = cpuNanoTime,
                actionExecutionTime = pathLength * configuration.actionDuration,
                goalAchievementTime = planningTime + pathLength * configuration.actionDuration,
                idlePlanningTime = planningTime,
                pathLength = pathLength,
                actions = actions.map(Action::toString))

    }
}