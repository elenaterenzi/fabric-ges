
## Difference between `-n` and `-z` in Bash

In Bash, `-n` and `-z` are used to test the length of a string.

- `-n STRING`: This returns true if the length of STRING is non-zero.
- `-z STRING`: This returns true if the length of STRING is zero.

### Examples

```bash
# Example of -n
if [ -n "$VAR" ]; then
    echo "VAR is not empty"
else
    echo "VAR is empty"
fi

# Example of -z
if [ -z "$VAR" ]; then
    echo "VAR is empty"
else
    echo "VAR is not empty"
fi
```

### Usage

- Use `-n` when you want to check if a string is not empty.
- Use `-z` when you want to check if a string is empty.
