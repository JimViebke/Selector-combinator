---@enum SelectorMode
SelectorMode = {
  ---sort the input signals in ascending or descending order, then output the signal at the specified index
  index = "index",
  ---count the number of input signals, then output the result
  count_inputs = "count_inputs",
  ---output a randomly selected signal from among the inputs
  random_input = "random_input",
  ---output the stack sizes of the input signals
  stack_size = "stack_size",
  ---transfer the quality of an input signal to the output signal(s)
  quality_transfer = "quality_transfer",
}
