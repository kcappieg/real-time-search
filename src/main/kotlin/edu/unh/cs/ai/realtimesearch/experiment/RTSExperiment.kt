package edu.unh.cs.ai.realtimesearch.experiment

import edu.unh.cs.ai.realtimesearch.agent.RTSAgent
import edu.unh.cs.ai.realtimesearch.environment.Action
import edu.unh.cs.ai.realtimesearch.environment.Environment
import edu.unh.cs.ai.realtimesearch.environment.State
import edu.unh.cs.ai.realtimesearch.experiment.configuration.ExperimentConfiguration
import edu.unh.cs.ai.realtimesearch.logging.info
import org.slf4j.LoggerFactory

/**
 * An RTS experiment repeatedly queries the agent
 * for an action by some constraint (allowed time for example).
 * After each selected action, the experiment then applies this action
 * to its environment.
 *
 * The states are given by the environment, the world. When creating the world
 * it might be possible to determine what the initial state is.
 *
 * NOTE: assumes the same domain is used to create both the agent as the world
 *
 * @param agent is a RTS agent that will supply the actions
 * @param world is the environment
 * @param terminationChecker controls the constraint put upon the agent
 * @param runs is the amount of runs you want the experiment to do
 */
class RTSExperiment<StateType : State<StateType>>(val experimentConfiguration: ExperimentConfiguration? = null,
                                                  val agent: RTSAgent<StateType>,
                                                  val world: Environment<StateType>,
                                                  val terminationChecker: TerminationChecker,
                                                  runs: Int = 1) : Experiment(runs) {

    private val logger = LoggerFactory.getLogger(RTSExperiment::class.java)

    /**
     * Runs the experiment
     */
    override fun run(): List<ExperimentResult> {
        val results: MutableList<ExperimentResult> = arrayListOf()

        for (run in 1..runs) {
            val actions: MutableList<Action> = arrayListOf()

            // init for this run
            agent.reset()
            world.reset()

            logger.info { "Starting experiment $run from state ${world.getState()}" }
            val timeInMillis = kotlin.system.measureTimeMillis {
                while (!world.isGoal()) {

                    terminationChecker.init()
                    val action = agent.selectAction(world.getState(), terminationChecker);

                    actions.add(action)
                    world.step(action)

                    logger.info { "Agent return action $action to state ${world.getState()}" }
                }
            }

            logger.info { "Path: [${actions.size}] $actions\nAfter ${agent.planner.expandedNodes} expanded and ${agent.planner.generatedNodes} generated nodes" }

            results.add(ExperimentResult(experimentConfiguration, agent.planner.expandedNodes, agent.planner.generatedNodes, timeInMillis, actions))
        }

        return results
    }
}