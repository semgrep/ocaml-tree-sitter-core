let { a, b = 2 } = foo;


function   prettierError(err) {
  let { details: _details = '', origin } = err;
}


const { object = {}, property = {} } = name;

// typescript only
//
// const {
//   reserved: isReservedNodeType = false,
// } = nodeAttrs;

let [/*match*/, theirName, myName = theirName] = tokens;
