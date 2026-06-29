for file in *.out; do
    if [[ -f "$file" ]]; then
        last_line=$(tail -n 3 "$file" 2>/dev/null)
        if [[ "$last_line" != *"finished without error"* ]]; then
            echo "$file"
        fi
    fi
done


for file in *.err; do
    if [[ -f "$file" ]]; then
        last_line=$(tail -n 1 "$file" 2>/dev/null)
        if [[ "$last_line" != *"PROCESSING DONE"* ]]; then
            echo "$file"
        fi
    fi
done


for file in *.out; do
    if [[ -f "$file" ]]; then
        last_line=$(tail -n 1 "$file" 2>/dev/null)
        if [[ "$last_line" != *"DONE"* ]]; then
            echo "$file"
        fi
    fi
done
