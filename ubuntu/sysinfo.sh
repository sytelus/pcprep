echo "System info" > sysinfo.txt
echo -e "\n *** GPU Matrx ***\n" >> sysinfo.txt
nvidia-smi topo --matrix
echo -e "\n *** CPU Info ***\n" >> sysinfo.txt
lscpu >> sysinfo.txt
echo -e "\n *** Mem Info ***\n" >> sysinfo.txt
lsmem >> sysinfo.txt
echo -e "\n *** GPU Info ***\n" >> sysinfo.txt
nvidia-smi -q >> sysinfo.txt
echo -e "\n *** NVlink Info ***\n" >> sysinfo.txt
nvidia-smi nvlink --capabilities >> sysinfo.txt
