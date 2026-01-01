BIDS_ROOT="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"

printf "%-15s | %-30s\n" "SUBJECT" "SESSION"
echo "------------------------------------------------"

find "$BIDS_ROOT" -name "*desc-defaced_T1w.nii.gz" | \
sed -E 's/.*(sub-[^/_]+).*(ses-[^/_]+).*/\1 \2/' | \
sort | uniq | \
while read sub ses; do
    printf "%-15s | %-30s\n" "$sub" "$ses"
done
