# H2O Sparkling Water integration with Conductor

Project to integrate H2O Sparkling Water as a notebook in IBM Spectrum Conductor.

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

