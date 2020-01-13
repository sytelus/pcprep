echo "System info"
echo -e "\n *** GPU Matrx ***\n"
nvidia-smi topo --matrix
echo -e "\n *** CPU Info ***\n"
lscpu
echo -e "\n *** Mem Info ***\n"
lsmem
echo -e "\n *** GPU Info ***\n"
nvidia-smi -q
echo -e "\n *** NVlink Info ***\n"
nvidia-smi nvlink --capabilities
