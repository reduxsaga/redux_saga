## Effects

### Blocking / Non-blocking

| Name                 | Blocking                                                    |
| -------------------- | ------------------------------------------------------------|
| TakeEvery            | :heavy_multiplication_x:                                    |
| TakeLatest           | :heavy_multiplication_x:                                    |
| TakeLeading          | :heavy_multiplication_x:                                    |
| Throttle             | :heavy_multiplication_x:                                    |
| Debounce             | :heavy_multiplication_x:                                    |
| Retry                | :heavy_check_mark:                                          |
| Take                 | :heavy_check_mark:                                          |
| TakeMaybe            | :heavy_check_mark:                                          |
| Put                  | :heavy_multiplication_x:                                    |
| PutResolve           | :heavy_check_mark:                                          |
| Call                 | :heavy_check_mark:                                          |
| Apply                | :heavy_check_mark:                                          |
| Try                  | :heavy_check_mark:                                          |
| TryReturn            | :heavy_check_mark:                                          |
| Cps                  | :heavy_check_mark:                                          |
| Fork                 | :heavy_multiplication_x:                                    |
| Spawn                | :heavy_multiplication_x:                                    |
| Join                 | :heavy_check_mark:                                          |
| Cancel               | :heavy_multiplication_x:                                    |
| Select               | :heavy_multiplication_x:                                    |
| ActionChannel        | :heavy_multiplication_x:                                    |
| Flush                | :heavy_check_mark:                                          |
| Cancelled            | :heavy_check_mark:                                          |
| Race                 | :heavy_check_mark:                                          |
| Delay                | :heavy_check_mark:                                          |
| All                  | Blocks if there is a blocking effect in the array or object |
| Return               | :heavy_check_mark:                                          |

