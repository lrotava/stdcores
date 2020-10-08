# -*- coding: utf-8 -*-
from os.path import join , dirname, abspath
import subprocess
from vunit.ghdl_interface import GHDLInterface
from vunit.simulator_factory import SIMULATOR_FACTORY
from vunit   import VUnit, VUnitCLI

##############################################################################
##############################################################################
##############################################################################

#Check GHDL backend.
code_coverage=False
try:
  if( GHDLInterface.determine_backend("")=="gcc" or  GHDLInterface.determine_backend("")=="GCC"):
    code_coverage=True
  else:
    code_coverage=False
except:
  print("")

#Check simulator.
print ("=============================================")
simulator_class = SIMULATOR_FACTORY.select_simulator()
simname = simulator_class.name
print (simname)
if (simname == "modelsim"):
  f= open("modelsim.do","w+")
  f.write("add wave * \nlog -r /*\nvcd file\nvcd add -r /*\n")
  f.close()
print ("=============================================")

##############################################################################
##############################################################################
##############################################################################

#VUnit instance.
ui = VUnit.from_argv()

##############################################################################
##############################################################################
##############################################################################

#Add array pkg.
ui.add_array_util()

ui.add_osvvm()
ui.add_array_util()
ui.add_verification_components()

#Add module sources.
run_src_lib = ui.add_library("stdblocks")
run_src_lib.add_source_files("../../../stdblocks/sync_lib/*.vhd", allow_empty=False)
run_src_lib = ui.add_library("stdcores")
run_src_lib.add_source_files("../../../stdcores/*/*.vhd", allow_empty=False)
run_src_lib = ui.add_library("expert")
run_src_lib.add_source_files("../../../stdexpert/src/*.vhd", allow_empty=False)

run_avl_utils_lib = ui.add_library("avl_utils_lib")
run_avl_utils_lib.add_source_files("../../../avl_packages/src/*.vhd", allow_empty=True)
run_avl_utils_lib.add_source_files("../../../stdexpert/src/*.vhd", allow_empty=False)
run_avl_utils_lib.add_source_files("../../../avl_clock_utils/src/*_pkg.vhd", allow_empty=False)


run_src_lib2 = ui.add_library("src_lib")
run_src_lib2.add_source_files("../../../avl_clock_utils/src/*.vhd", allow_empty=False)


run_avl_sim_lib = ui.add_library("avl_sim_lib")
run_avl_sim_lib.add_source_files("../../../avl_simulators/src/*.vhd", allow_empty=True)

#Add tb sources.
run_tb_lib = ui.add_library("tb_lib")
run_tb_lib.add_source_files("*.vhd")

##############################################################################
##############################################################################
##############################################################################

#GHDL parameters.
if(code_coverage==True):
  run_src_lib.add_compile_option("ghdl.flags", [  "-fprofile-arcs","-ftest-coverage" ])
  run_tb_lib.add_compile_option("ghdl.flags", [ "-fprofile-arcs","-ftest-coverage" ])
  ui.set_sim_option("ghdl.elab_flags", [ "-Wl,-lgcov","-Wl,--coverage" ])
  ui.set_sim_option("modelsim.init_files.after_load" ,["modelsim.do"])
else:
  ui.set_sim_option("modelsim.init_files.after_load" ,["modelsim.do"])


#Run tests.
try:
  ui.main()
except SystemExit as exc:
  all_ok = exc.code == 0

#Code coverage.
if all_ok:
  if(code_coverage==True):
    subprocess.run(["lcov", "--capture", "--directory", ".", "--output-file",  "code_coverage.info" ])
    subprocess.run(["genhtml","code_coverage.info","--output-directory", "cc_html"])
    
    # Remove all the code coverage intermediate files
    subprocess.run('rm *.gcno *.gcda code_coverage.info', shell=True)
  else:
    # Remove all the code coverage intermediate files
    subprocess.run('rm *.gcno *.gcda code_coverage.info', shell=True)
    exit(0)
else:
  # Remove all the code coverage intermediate files
  subprocess.run('rm *.gcno *.gcda code_coverage.info', shell=True)
  exit(1)
