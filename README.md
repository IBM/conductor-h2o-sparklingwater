# H2O Sparkling Water integration with Conductor

### This is a fork of IBM Conductor for changes needed for later Sparkling Water versions
Project to integrate H2O Sparkling Water as a notebook in IBM Spectrum Conductor.

### Sparkling Water was tested on following versions:
IBM SC 2.5.0:
- SW 3.32.1.7 with Spark 2.4 and Spark 3.0

IBM SC 2.5.1:
- SW 3.32.1.7 with Spark 2.4 and Spark 3.0
- SW 3.34.0.8 with Spark 2.4 and Spark 3.0


#### NOTE: This repo is using SW 3.32.1.7 on Spark 2.4 as an example. However, other versions could be used. 

### Using:
Download [H2O Sparkling Water](https://www.h2o.ai/download) and place it in the package folder. In the scripts/common.inc file update the version from 3.32.1.7-1-2.4 to the version you are using if it is different. Then run the build_package.sh script to build the package.

Then you can add this package (example: H2O_Sparklingwater-3.32.1.7.tgz) to your Conductor cluster through the "Add" button on "Workload" / "Spark" / "Notebook Management" page.
Parameters you have to define:
- Name
- Version (typically the version of H2O Sparkling Water, example 3.32.1.7)
- Prestart command: ./scripts/notebookservicewrapper.sh prestart_nb.sh
- Start command: ./scripts/notebookservicewrapper.sh start_nb.sh
- Stop command: ./scripts/stop_nb.sh
- Job monitor command: ./scripts/jobMonitor.sh

Additional environment variables: H2O_SPARK_CONF = --conf spark.ext.h2o.nthreads=1 --conf spark.driver.memory=8g

Then you can add it to an existing Spark Instance Group (you need to stop it then go to the configuration page) or create a new Spark Instance Group with it.
 
In the Spark instance group configuration you need to set:
- SPARK_EGO_ENABLE_PREEMPTION=false
- SPARK_EGO_FREE_SLOTS_IDLE_TIMEOUT=3000
- SPARK_EGO_EXECUTOR_IDLE_TIMEOUT=3000
- SPARK_EXECUTOR_MEMORY=8g
- JAVA_HOME to the location of Open JDK, example /usr

**Optional:**

- SPARK_EGO_SLOTS_PER_TASK and SPARK_EGO_EXECUTOR_SLOTS_MAX can be both be set to 1, if you expect executors and slots to match. Otherwise an executor may take multiple slots.
- When restricting the size of the H2O Sparkling Water cluster set **spark.ego.slots.max** and **spark.ego.slots.required** and **spark.ext.h2o.cluster.size** to the same number of slots you want the cluster to take.

**If another version of Sparkling Water is used.** Make sure to update version numbers for these files: build_package.sh, metadata.yml, scripts/common.inc

