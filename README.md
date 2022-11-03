# H2O Sparkling Water integration with Conductor

The repository allows building H2O Sparkling Water as a notebook for IBM Spectrum Conductor. That serves as a way to deploy H2O-3.

## Building the package
To build the package clone the repo and run the script providing the Sparkling Water Version:

`./build_package.sh sparkling_water_version`

For example: 

`./build_package.sh 3.38.0.1-1-3.0`

That will download Sparkling Water (if the .zip file is not already present in the root directory) and build the package.
Then the .tar.gz package will be available under the `/build` directory (for example `/build/h2o-sparkling-water-3.38.0.1-1-3.0.tar.gz`)

## Adding the Sparkling Water Package to IBM Spectrum Conductor
Add the package (example: `h2o-sparkling-water-3.38.0.1-1-3.0.tar.gz`) to your Conductor cluster through the "Spark" / "Notebook Management" page (can be a little different depending on Spectrum Conductor version).
Parameters you have to define:
- Name
- Version (typically the version of H2O Sparkling Water, example 3.38.0.1)
- Prestart command: `./scripts/notebookservicewrapper.sh prestart_nb.sh`
- Start command: `./scripts/notebookservicewrapper.sh start_nb.sh`
- Stop command: `./scripts/stop_nb.sh`
- Job monitor command: `./scripts/jobMonitor.sh`

* Additional environment variables: `H2O_SPARK_CONF=--conf spark.ext.h2o.nthreads=1 --conf spark.driver.memory=8g`

Then you can add it to an existing Spark Instance Group (you need to stop it then go to the configuration page) or create a new Spark Instance Group with it.

In the Spark instance group configuration you need to set:
- `SPARK_EGO_ENABLE_PREEMPTION=false`
- `SPARK_EGO_FREE_SLOTS_IDLE_TIMEOUT=3000`
- `SPARK_EGO_EXECUTOR_IDLE_TIMEOUT=3000`
- `SPARK_EXECUTOR_MEMORY=8g`
- `JAVA_HOME` to the location of Open JDK, example `/usr/lib/jvm/java`

**Optional:**

- `SPARK_EGO_SLOTS_PER_TASK` and `SPARK_EGO_EXECUTOR_SLOTS_MAX` can be both be set to `1`, if you expect executors and slots to match. Otherwise an executor may take multiple slots.
- When restricting the size of the H2O Sparkling Water cluster set `spark.ego.slots.max` and `spark.ego.slots.required` and `spark.ext.h2o.cluster.size` to the same number of slots you want the cluster to take.

