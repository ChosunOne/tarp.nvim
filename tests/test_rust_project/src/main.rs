fn some_function(a: usize, b: usize) {
    println!("Hello world!");
    if a < b {
        println!("a < b");
    }
}

pub fn main() {
    some_function(1, 2);
}

fn uncovered_function() {
    let a = 2;
    let b = 3;
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn it_runs_a_test() {
        main()
    }

    #[test]
    fn it_runs_a_test_2() {
        some_function(2, 1);
    }
}
