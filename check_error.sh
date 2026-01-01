for file in *.out; do
    if [[ -f "$file" ]]; then
        last_line=$(tail -n 3 "$file" 2>/dev/null)
        if [[ "$last_line" != *"finished without error"* ]]; then
            echo "$file"
        fi
    fi
done
