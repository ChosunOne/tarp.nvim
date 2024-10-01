fn some_function() {
    println!("Hello world!");
}

pub fn main() {
    some_function();
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn it_runs_a_test() {
        main()
    }
}
